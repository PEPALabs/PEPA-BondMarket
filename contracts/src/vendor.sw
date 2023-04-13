contract;

use std::{
    address::*,
    assert::assert,
    block::*,
    // chain::auth::*,
    context::*,
    contract_id::ContractId,
    constants::*,
    external::bytecode_root,
    hash::*,
    result::*,
    revert::revert,
    storage::*,
    token::*,
    u128::U128,
    //comment out forc 0.33.1 import
    auth::*,
    call_frames::{contract_id, msg_asset_id},
};

pub enum VendorError {
  PlaceholderError: (),
}

// TODO: fix datatype: u256 -> u64 in Sway
// TODO: fix external view override

// function prototypes
abi Vendor{

    // initialize vendor
    #[storage(read,write)]
    fn initialize();

    // create a bond market
    #[storage(read, write)]
    fn create_market(params: b256) -> b256;

    // close a bond market
    #[storage(read, write)]
    fn close_market(market_id: b256) -> b256;

    // pay quote tokens for a bond in market
    #[storage(read, write)]
    fn purchase_bond(market_id: b256, amount: u256, min_amount: u256) -> u256;

    // set market intervals to different values than the defaults
    #[storage(read, write)]
    fn set_intervals(market_id: b256, intervals: [u32, u32], interval_0: u32, interval_1: u32, interval_2: u32);

    // designate a new owner of a market
    #[storage(read, write)]
    fn push_ownership(market_id: b256, owner: address);

    // accept ownership of a market
    #[storage(read, write)]
    fn pull_ownership(market_id: b256);

    // set vendor defaults
    #[storage(read, write)]
    fn set_defaults(defaults: [u32, u32], default_0: u32, default_1: u32, default_2: u32, default_3: u32, default_4: u32, default_5: u32);

    // provides info for seller to execute purchases on a market
    // TOOD: return multiple items
    #[storage(read)]
    fn get_market_info_for_purchase(market_id: b256) -> [struct, address, struct, b256, b256, u64, u256];

    // calculate current market price of payout token in quote tokens
    #[storage(read)]
    fn market_price(market_id: b256) -> u256;

    // scale value to use when converting between quote token and payout token amounts with market_price()
    #[storage(read)]
    fn market_scale(market_id: b256) -> u256;

    // payout due for amount of quote tokens
    #[storage(read, write)]
    fn payout_for(market_id: b256, amount: u256) -> address;

    // returns maximum amount of quote token accepted by market
    #[storage(read)]
    fn max_amount_accepted(market_id: b256, referrer: address) -> u256;

    // check if market sends payout immediately
    #[storage(read)]
    fn is_instant_swap(market_id: b256) -> bool;

    // check if market accepts deposits
    #[storage(read)]
    fn is_live(market_id: b256) -> bool;

    // returns seller that serives the market
    #[storage(read)]
    fn get_seller(market_id: b256) -> b256;

    // get current capacity of a market
    #[storage(read)]
    fn current_capacity(market_id: b256) -> u256;

    // returns address of the market owner
    #[storage(read)]
    fn owner_of(market_id: b256) -> address;

    // returns floor that services vendor
    #[storage(read)]
    fn get_floor() -> b256;

}

// TODO: continue modification from here
storage {
    template_root: b256 = ZERO_B256, 
    swap_pair: StorageMap<(b256, b256), b256> = StorageMap {},
    swap_address: StorageMap<b256, bool> = StorageMap {},
}

// TODO: rename auctioneer -> ...
impl Vendor for Contract {

    // initialize floor
    #[storage(read, write)]
    fn initialize(){
    }

    // create a bond market
    // from: BondBaseSDA.sol
    #[storage(read, write)]
    fn create_market(params: b256){
        {
            // Check that the auctioneer is allowing new markets to be created
            if (!allowNewMarkets) revert Auctioneer_NewMarketsNotAllowed();

            // Ensure params are in bounds
            uint8 payoutTokenDecimals = params_.payoutToken.decimals();
            uint8 quoteTokenDecimals = params_.quoteToken.decimals();

            if (payoutTokenDecimals < 6 || payoutTokenDecimals > 18)
                revert Auctioneer_InvalidParams();
            if (quoteTokenDecimals < 6 || quoteTokenDecimals > 18)
                revert Auctioneer_InvalidParams();
            if (params_.scaleAdjustment < -24 || params_.scaleAdjustment > 24)
                revert Auctioneer_InvalidParams();

            // Restrict the use of a callback address unless allowed
            if (!callbackAuthorized[msg.sender] && params_.callbackAddr != address(0))
                revert Auctioneer_NotAuthorized();
        }

        // Unit to scale calculation for this market by to ensure reasonable values
        // for price, debt, and control variable without under/overflows.
        // See IBondSDA for more details.
        //
        // scaleAdjustment should be equal to (payoutDecimals - quoteDecimals) - ((payoutPriceDecimals - quotePriceDecimals) / 2)
        uint256 scale;
        unchecked {
            scale = 10**uint8(36 + params_.scaleAdjustment);
        }

        if (params_.formattedInitialPrice < params_.formattedMinimumPrice)
            revert Auctioneer_InitialPriceLessThanMin();

        // Register new market on aggregator and get marketId
        uint256 marketId = _aggregator.registerMarket(params_.payoutToken, params_.quoteToken);

        uint32 secondsToConclusion;
        uint32 debtDecayInterval;
        {
            // Conclusion must be later than the current block timestamp or will revert
            secondsToConclusion = uint32(params_.conclusion - block.timestamp);
            if (
                secondsToConclusion < minMarketDuration ||
                params_.depositInterval < minDepositInterval ||
                params_.depositInterval > secondsToConclusion
            ) revert Auctioneer_InvalidParams();

            // The debt decay interval is how long it takes for price to drop to 0 from the last decay timestamp.
            // In reality, a 50% drop is likely a guaranteed bond sale. Therefore, debt decay interval needs to be
            // long enough to allow a bond to adjust if oversold. It also needs to be some multiple of deposit interval
            // because you don't want to go from 100 to 0 during the time frame you expected to sell a single bond.
            // A multiple of 5 is a sane default observed from running OP v1 bond markets.
            uint32 userDebtDecay = params_.depositInterval * 5;
            debtDecayInterval = minDebtDecayInterval > userDebtDecay
                ? minDebtDecayInterval
                : userDebtDecay;

            uint256 tuneIntervalCapacity = params_.capacity.mulDiv(
                uint256(
                    params_.depositInterval > defaultTuneInterval
                        ? params_.depositInterval
                        : defaultTuneInterval
                ),
                uint256(secondsToConclusion)
            );

            metadata[marketId] = BondMetadata({
                lastTune: uint48(block.timestamp),
                lastDecay: uint48(block.timestamp),
                length: secondsToConclusion,
                depositInterval: params_.depositInterval,
                tuneInterval: params_.depositInterval > defaultTuneInterval
                    ? params_.depositInterval
                    : defaultTuneInterval,
                tuneAdjustmentDelay: defaultTuneAdjustment,
                debtDecayInterval: debtDecayInterval,
                tuneIntervalCapacity: tuneIntervalCapacity,
                tuneBelowCapacity: params_.capacity - tuneIntervalCapacity,
                lastTuneDebt: (
                    params_.capacityInQuote
                        ? params_.capacity.mulDiv(scale, params_.formattedInitialPrice)
                        : params_.capacity
                ).mulDiv(uint256(debtDecayInterval), uint256(secondsToConclusion))
            });
        }

        // Initial target debt is equal to capacity scaled by the ratio of the debt decay interval and the length of the market.
        // This is the amount of debt that should be decayed over the decay interval if no purchases are made.
        // Note price should be passed in a specific format:
        // price = (payoutPriceCoefficient / quotePriceCoefficient)
        //         * 10**(36 + scaleAdjustment + quoteDecimals - payoutDecimals + payoutPriceDecimals - quotePriceDecimals)
        // See IBondSDA for more details and variable definitions.
        uint256 targetDebt;
        uint256 maxPayout;
        {
            uint256 capacity = params_.capacityInQuote
                ? params_.capacity.mulDiv(scale, params_.formattedInitialPrice)
                : params_.capacity;

            targetDebt = capacity.mulDiv(uint256(debtDecayInterval), uint256(secondsToConclusion));

            // Max payout is the amount of capacity that should be utilized in a deposit
            // interval. for example, if capacity is 1,000 TOKEN, there are 10 days to conclusion,
            // and the preferred deposit interval is 1 day, max payout would be 100 TOKEN.
            // Additionally, max payout is the maximum amount that a user can receive from a single
            // purchase at that moment in time.
            maxPayout = capacity.mulDiv(
                uint256(params_.depositInterval),
                uint256(secondsToConclusion)
            );
        }

        markets[marketId] = BondMarket({
            owner: msg.sender,
            payoutToken: params_.payoutToken,
            quoteToken: params_.quoteToken,
            callbackAddr: params_.callbackAddr,
            capacityInQuote: params_.capacityInQuote,
            capacity: params_.capacity,
            totalDebt: targetDebt,
            minPrice: params_.formattedMinimumPrice,
            maxPayout: maxPayout,
            purchased: 0,
            sold: 0,
            scale: scale
        });

        // Max debt serves as a circuit breaker for the market. let's say the quote token is a stablecoin,
        // and that stablecoin depegs. without max debt, the market would continue to buy until it runs
        // out of capacity. this is configurable with a 3 decimal buffer (1000 = 1% above initial price).
        // Note that its likely advisable to keep this buffer wide.
        // Note that the buffer is above 100%. i.e. 10% buffer = initial debt * 1.1
        // 1e5 = 100,000. 10,000 / 100,000 = 10%.
        // See IBondSDA.MarketParams for more information on determining a reasonable debt buffer.
        uint256 minDebtBuffer_ = maxPayout.mulDiv(FEE_DECIMALS, targetDebt) > minDebtBuffer
            ? maxPayout.mulDiv(FEE_DECIMALS, targetDebt)
            : minDebtBuffer;
        uint256 maxDebt = targetDebt +
            targetDebt.mulDiv(
                uint256(params_.debtBuffer > minDebtBuffer_ ? params_.debtBuffer : minDebtBuffer_),
                1e5
            );

        // The control variable is set as the ratio of price to the initial targetDebt, scaled to prevent under/overflows.
        // It determines the price of the market as the debt decays and is tuned by the market based on user activity.
        // See _tune() for more information.
        //
        // price = control variable * debt / scale
        // therefore, control variable = price * scale / debt
        uint256 controlVariable = params_.formattedInitialPrice.mulDiv(scale, targetDebt);

        terms[marketId] = BondTerms({
            controlVariable: controlVariable,
            maxDebt: maxDebt,
            vesting: params_.vesting,
            conclusion: params_.conclusion
        });

        emit MarketCreated(
            marketId,
            address(params_.payoutToken),
            address(params_.quoteToken),
            params_.vesting,
            params_.formattedInitialPrice
        );

        return marketId;
    }

    // close a bond market
    #[storage(read, write)]
    fn close_market(market_id: b256){
        if (msg.sender != markets[id_].owner) revert Auctioneer_OnlyMarketOwner();
        _close(id_);
    }

    // pay quote tokens for a bond in market
    #[storage(read, write)]
    fn purchase_bond(market_id: b256, amount: u256, min_amount: u256){
        if (msg.sender != address(_teller)) revert Auctioneer_NotAuthorized();

        BondMarket storage market = markets[id_];
        BondTerms memory term = terms[id_];

        // If market uses a callback, check that owner is still callback authorized
        if (market.callbackAddr != address(0) && !callbackAuthorized[market.owner])
            revert Auctioneer_NotAuthorized();

        // Markets end at a defined timestamp
        uint48 currentTime = uint48(block.timestamp);
        if (currentTime >= term.conclusion) revert Auctioneer_MarketConcluded(term.conclusion);

        uint256 price;
        (price, payout) = _decayAndGetPrice(id_, amount_, uint48(block.timestamp)); // Debt and the control variable decay over time

        // Payout must be greater than user inputted minimum
        if (payout < minAmountOut_) revert Auctioneer_AmountLessThanMinimum();

        // Markets have a max payout amount, capping size because deposits
        // do not experience slippage. max payout is recalculated upon tuning
        if (payout > market.maxPayout) revert Auctioneer_MaxPayoutExceeded();

        // Update Capacity and Debt values

        // Capacity is either the number of payout tokens that the market can sell
        // (if capacity in quote is false),
        //
        // or the number of quote tokens that the market can buy
        // (if capacity in quote is true)

        // If amount/payout is greater than capacity remaining, revert
        if (market.capacityInQuote ? amount_ > market.capacity : payout > market.capacity)
            revert Auctioneer_NotEnoughCapacity();
        // Capacity is decreased by the deposited or paid amount
        market.capacity -= market.capacityInQuote ? amount_ : payout;

        // Markets keep track of how many quote tokens have been
        // purchased, and how many payout tokens have been sold
        market.purchased += amount_;
        market.sold += payout;

        // Circuit breaker. If max debt is breached, the market is closed
        if (term.maxDebt < market.totalDebt) {
            _close(id_);
        } else {
            // If market will continue, the control variable is tuned to to expend remaining capacity over remaining market duration
            _tune(id_, currentTime, price);
        }
    }

    // set market intervals to different values than the defaults
    #[storage(read, write)]
    fn set_intervals(market_id: b256, intervals: [u32, u32], interval_0: u32, interval_1: u32, interval_2: u32){
        // Check that the market is live
        if (!isLive(id_)) revert Auctioneer_InvalidParams();

        // Check that the intervals are non-zero
        if (intervals_[0] == 0 || intervals_[1] == 0 || intervals_[2] == 0)
            revert Auctioneer_InvalidParams();

        // Check that tuneInterval >= tuneAdjustmentDelay
        if (intervals_[0] < intervals_[1]) revert Auctioneer_InvalidParams();

        BondMetadata storage meta = metadata[id_];
        // Check that tuneInterval >= depositInterval
        if (intervals_[0] < meta.depositInterval) revert Auctioneer_InvalidParams();

        // Check that debtDecayInterval >= minDebtDecayInterval
        if (intervals_[2] < minDebtDecayInterval) revert Auctioneer_InvalidParams();

        // Check that sender is market owner
        BondMarket memory market = markets[id_];
        if (msg.sender != market.owner) revert Auctioneer_OnlyMarketOwner();

        // Update intervals
        meta.tuneInterval = intervals_[0];
        meta.tuneIntervalCapacity = market.capacity.mulDiv(
            uint256(intervals_[0]),
            uint256(terms[id_].conclusion) - block.timestamp
        ); // don't have a stored value for market duration, this will update tuneIntervalCapacity based on time remaining
        meta.tuneBelowCapacity = market.capacity > meta.tuneIntervalCapacity
            ? market.capacity - meta.tuneIntervalCapacity
            : 0;
        meta.tuneAdjustmentDelay = intervals_[1];
        meta.debtDecayInterval = intervals_[2];
    }

    // designate a new owner of a market
    #[storage(read, write)]
    fn push_ownership(market_id: b256, owner: address){
        if (msg.sender != markets[id_].owner) revert Auctioneer_OnlyMarketOwner();
        newOwners[id_] = newOwner_;
    }

    // accept ownership of a market
    #[storage(read, write)]
    fn pull_ownership(market_id: b256){
        if (msg.sender != newOwners[id_]) revert Auctioneer_NotAuthorized();
        markets[id_].owner = newOwners[id_];
    }

    // set vendor defaults
    #[storage(read, write)]
    fn set_defaults(defaults: [u32, u32], default_0: u32, default_1: u32, default_2: u32, default_3: u32, default_4: u32, default_5: u32){
        // Restricted to authorized addresses

        // Validate inputs
        // Check that defaultTuneInterval >= defaultTuneAdjustment
        if (defaults_[0] < defaults_[1]) revert Auctioneer_InvalidParams();

        // Check that defaultTuneInterval >= minDepositInterval
        if (defaults_[0] < defaults_[3]) revert Auctioneer_InvalidParams();

        // Check that minDepositInterval <= minMarketDuration
        if (defaults_[3] > defaults_[4]) revert Auctioneer_InvalidParams();

        // Check that minDebtDecayInterval >= 5 * minDepositInterval
        if (defaults_[2] < defaults_[3] * 5) revert Auctioneer_InvalidParams();

        // Update defaults
        defaultTuneInterval = defaults_[0];
        defaultTuneAdjustment = defaults_[1];
        minDebtDecayInterval = defaults_[2];
        minDepositInterval = defaults_[3];
        minMarketDuration = defaults_[4];
        minDebtBuffer = defaults_[5];

        emit DefaultsUpdated(
            defaultTuneInterval,
            defaultTuneAdjustment,
            minDebtDecayInterval,
            minDepositInterval,
            minMarketDuration,
            minDebtBuffer
        );
    }

    // provides info for seller to execute purchases on a market
    // TOOD: return multiple items
    #[storage(read)]
    fn get_market_info_for_purchase(market_id: b256){
        BondMarket memory market = markets[id_];
        return (
            market.owner,
            market.callbackAddr,
            market.payoutToken,
            market.quoteToken,
            terms[id_].vesting,
            market.maxPayout
        );
    }

    // calculate current market price of payout token in quote tokens
    #[storage(read)]
    fn market_price(market_id: b256){
        uint256 price = currentControlVariable(id_).mulDivUp(currentDebt(id_), markets[id_].scale);
        return (price > markets[id_].minPrice) ? price : markets[id_].minPrice;
    }

    // scale value to use when converting between quote token and payout token amounts with market_price()
    #[storage(read)]
    fn market_scale(market_id: b256){
        return markets[id_].scale;
    }

    // payout due for amount of quote tokens
    #[storage(read, write)]
    fn payout_for(market_id: b256, amount: u256){
        // Calculate the payout for the given amount of tokens
        uint256 fee = amount_.mulDiv(_teller.getFee(referrer_), 1e5);
        uint256 payout = (amount_ - fee).mulDiv(markets[id_].scale, marketPrice(id_));

        // Check that the payout is less than or equal to the maximum payout,
        // Revert if not, otherwise return the payout
        if (payout > markets[id_].maxPayout) {
            revert Auctioneer_MaxPayoutExceeded();
        } else {
            return payout;
        }
    }

    // returns maximum amount of quote token accepted by market
    #[storage(read)]
    fn max_amount_accepted(market_id: b256, referrer: address){
        // Calculate maximum amount of quote tokens that correspond to max bond size
        // Maximum of the maxPayout and the remaining capacity converted to quote tokens
        BondMarket memory market = markets[id_];
        uint256 price = marketPrice(id_);
        uint256 quoteCapacity = market.capacityInQuote
            ? market.capacity
            : market.capacity.mulDiv(price, market.scale);
        uint256 maxQuote = market.maxPayout.mulDiv(price, market.scale);
        uint256 amountAccepted = quoteCapacity < maxQuote ? quoteCapacity : maxQuote;

        // Take into account teller fees and return
        // Estimate fee based on amountAccepted. Fee taken will be slightly larger than
        // this given it will be taken off the larger amount, but this avoids rounding
        // errors with trying to calculate the exact amount.
        // Therefore, the maxAmountAccepted is slightly conservative.
        uint256 estimatedFee = amountAccepted.mulDiv(_teller.getFee(referrer_), 1e5);

        return amountAccepted + estimatedFee;
    }

    // check if market sends payout immediately
    #[storage(read)]
    fn is_instant_swap(market_id: b256){
        uint256 vesting = terms[id_].vesting;
        return (vesting <= MAX_FIXED_TERM) ? vesting == 0 : vesting <= block.timestamp;
    }

    // check if market accepts deposits
    #[storage(read)]
    fn is_live(market_id: b256){
        return (markets[id_].capacity != 0 && terms[id_].conclusion > block.timestamp);
    }

    // returns seller that serives the market
    // TODO: teller -> seller
    #[storage(read)]
    fn get_seller(market_id: b256){
        return _teller;
    }

    // get current capacity of a market
    #[storage(read)]
    fn current_capacity(market_id: b256){
        return markets[id_].capacity;
    }

    // returns address of the market owner
    #[storage(read)]
    fn owner_of(market_id: b256){
        return markets[id_].owner;
    }

    // returns floor that services vendor
    // TODO: addgregator -> floor
    #[storage(read)]
    fn get_floor(){
        return _aggregator;
    }

}