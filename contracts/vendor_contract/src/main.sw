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
    u256::U256,
    //comment out forc 0.33.1 import
    auth::*,
    call_frames::{contract_id, msg_asset_id},
};

use vendor_abi::*;
use floor_abi::*;
use seller_abi::*;

const MAX_FIXED_TERM = U256::from((0,0,0,1572480000));
const FEE_DECIMALS = U256::from((0,0,0,100000));
const ONE_U256 = U256::from((0,0,0,1));
const NO_ADJUSTMENT = Adjustment {
    change: U256::min(),
    last_adjustment: U256::min(),
    time_to_adjusted: U256::min(),
    active: false,
};


// TODO: fix datatype: u256 -> u64 in Sway
// TODO: fix external view override

// TODO: continue modification from here
storage {
    template_root: b256 = ZERO_B256, 
    markets: StorageMap<u64, BondMarket> = StorageMap {},
    terms: StorageMap<u64, BondTerms> = StorageMap {},
    metadata: StorageMap<u64, BondMetadata> = StorageMap {},
    adjustments: StorageMap<u64, Adjustment> = StorageMap {},
    new_owners: StorageMap<u64, b256> = StorageMap {},
    callback_authorized: StorageMap<b256, bool> = StorageMap {},
    allow_new_markets: bool = false,
    floor: b256 = ZERO_B256,
    seller: b256 = ZERO_B256,
    default_tune_interval: U256 = U256::min(),
    default_tune_adjustment: U256 = U256::min(),
    min_debt_decay_interval: U256 = U256::min(),
    min_deposit_interval: U256 = U256::min(),
    min_market_duration: U256 = U256::min(),
    min_debt_buffer: U256 = U256::min(),
}

#[storage(read)]
fn current_debt(market_id: u64) -> U256{
    let meta = storage.metadata.get(market_id).unwrap();
    let market = storage.markets.get(market_id).unwrap();
    let last_decay = meta.last_decay;
    let curr_time = u64_to_u256(timestamp());
    let mut ret = U256::min();

    if last_decay > curr_time {
        let seconds_until = last_decay - curr_time;
        ret = market.total_debt * (meta.debt_decay_interval + seconds_until) / meta.debt_decay_interval;
    } else {
        let seconds_since = curr_time - last_decay;
        ret = if seconds_since > meta.debt_decay_interval {
            U256::min()
        } else {
            market.total_debt * (meta.debt_decay_interval - seconds_since) / meta.debt_decay_interval
        };
    }
    ret
}

#[storage(read)]
fn control_decay(market_id: u64) -> (U256, U256, bool) {
    let info = storage.adjustments.get(market_id).unwrap_or(NO_ADJUSTMENT);
    if (!info.active) {
        return (U256::min(),U256::min(),false);
    }

    let seconds_since = u64_to_u256(timestamp()) - info.last_adjustment;
    let active = (seconds_since < info.time_to_adjusted);
    let decay = if active {
        info.change * seconds_since / info.time_to_adjusted
    } else {
        info.change
    };

    (decay, seconds_since, active)
}

#[storage(read)]
fn current_market_price(id: u64)-> U256 {
    let market = storage.markets.get(id).unwrap();
    let term = storage.terms.get(id).unwrap();
    let ret = (term.control_variable * market.total_debt + market.scale - ONE_U256) / market.scale;
    ret
}

#[storage(read)]
fn is_live_(id: u64)->bool{
    let market = storage.markets.get(id).unwrap();
    let term = storage.terms.get(id).unwrap();
    market.capacity != U256::min() && term.conclusion > u64_to_u256(timestamp())
}

#[storage(read)]
fn market_price_(id: u64) -> U256{
    let (decay, _, _) = control_decay(id);
    let term = storage.terms.get(id).unwrap();
    let market = storage.markets.get(id).unwrap();
    let new_control_variable = term.control_variable - decay;
    let price = (new_control_variable * current_debt(id) + market.scale - ONE_U256) / market.scale;

    if price > market.min_price {
        price
    } else {
        market.min_price
    }
}

fn u256_to_u64(num: U256) -> u64 {
    let res = num.as_u64();
    require(!res.is_err(), VendorError::U256ConvertOverflow);
    res.unwrap()
}

fn exp_to_u256(exp: u64) -> U256 {
    let mut res = U256::from((0,0,0,1));
    let mut cur = exp;
    while cur > 0 {
        res = res * U256::from((0,0,0,10));
        cur = cur - 1;
    }
    res
}

fn u64_to_u256(num: u64) -> U256 {
    U256::from((0,0,0,num))
}

// TODO: rename auctioneer -> ...
impl Vendor for Contract {

    // initialize floor
    #[storage(read, write)]
    fn initialize(seller_: b256, floor_: b256){
        storage.seller = seller_;
        storage.floor = floor_;

        storage.default_tune_interval = u64_to_u256(24*3600);
        storage.default_tune_adjustment = u64_to_u256(3600);
        storage.min_debt_decay_interval = u64_to_u256(3 * 24 * 3600);
        storage.min_deposit_interval = u64_to_u256(3600);
        storage.min_market_duration = u64_to_u256(24 * 3600);
        storage.min_debt_buffer = u64_to_u256(10000);

        storage.allow_new_markets = true;
    }

    // create a bond market
    // from: BondBaseSDA.sol
    #[storage(read, write)]
    fn create_market(params: MarketParams)-> u64{
        // Check that the auctioneer is allowing new markets to be created
        require(storage.allow_new_markets, VendorError::NewMarketsNotAllowed);

        // Ensure params are in bounds
        let payoutTokenDecimals = u64_to_u256(9);
        let quoteTokenDecimals = u64_to_u256(9);

        // if (payoutTokenDecimals < 6 || payoutTokenDecimals > 18)
        //     revert Auctioneer_InvalidParams();
        // if (quoteTokenDecimals < 6 || quoteTokenDecimals > 18)
        //     revert Auctioneer_InvalidParams();
        // TODO: add sign
        require(params.scale_adjustment <= 24, VendorError::InvalidParams);

        // Restrict the use of a callback address unless allowed
        let sender = msg_sender().unwrap();
        let addr:Address = match sender {
            Identity::Address(identity) => identity,
            _ => revert(0),
        };
        require(storage.callback_authorized.get(addr.into()).unwrap_or(false) || params.callback_addr == ZERO_B256, VendorError::NotAuthorized);

        // Unit to scale calculation for this market by to ensure reasonable values
        // for price, debt, and control variable without under/overflows.
        // See IBondSDA for more details.
        //
        // scaleAdjustment should be equal to (payoutDecimals - quoteDecimals) - ((payoutPriceDecimals - quotePriceDecimals) / 2)
        let adjusted_exp = if params.scale_adjustment_positive {
            18 + params.scale_adjustment
        } else {
            18 - params.scale_adjustment
        };

        let scale = exp_to_u256(adjusted_exp);

        let formatted_initial_price = u64_to_u256(params.formatted_initial_price.0) * exp_to_u256(params.formatted_initial_price.2) / u64_to_u256(params.formatted_initial_price.1);
        let formatted_minimum_price = u64_to_u256(params.formatted_minimum_price.0) * exp_to_u256(params.formatted_minimum_price.2) / u64_to_u256(params.formatted_minimum_price.1);

        require(formatted_initial_price > formatted_minimum_price || formatted_initial_price == formatted_minimum_price, VendorError::InitialPriceLessThanMin);

        // Register new market on aggregator and get marketId
        let aggregator = abi(Floor, storage.floor);
        let market_id = aggregator.register_market(params.payout_token, params.quote_token);

        // Conclusion must be later than the current block timestamp or will revert
        let seconds_to_conclusion = u64_to_u256(params.conclusion - timestamp());
        require(
            (seconds_to_conclusion > storage.min_market_duration || seconds_to_conclusion == storage.min_market_duration)
            && (u64_to_u256(params.deposit_interval) > storage.min_deposit_interval || u64_to_u256(params.deposit_interval) == storage.min_deposit_interval)
            && (u64_to_u256(params.deposit_interval) < seconds_to_conclusion || u64_to_u256(params.deposit_interval) == seconds_to_conclusion)
            ,VendorError::InvalidParams
        );

        // The debt decay interval is how long it takes for price to drop to 0 from the last decay timestamp.
        // In reality, a 50% drop is likely a guaranteed bond sale. Therefore, debt decay interval needs to be
        // long enough to allow a bond to adjust if oversold. It also needs to be some multiple of deposit interval
        // because you don't want to go from 100 to 0 during the time frame you expected to sell a single bond.
        // A multiple of 5 is a sane default observed from running OP v1 bond markets.
        let user_debt_decay = u64_to_u256(params.deposit_interval * 5);
        let debt_decay_interval = if storage.min_debt_decay_interval > user_debt_decay {
            storage.min_debt_decay_interval
        } else {
            user_debt_decay
        };

        let tmp = if u64_to_u256(params.deposit_interval) > storage.default_tune_interval {
            u64_to_u256(params.deposit_interval)
        } else {
            storage.default_tune_interval
        };

        let tune_interval_capacity = u64_to_u256(params.capacity) * tmp / seconds_to_conclusion;
        let tune_interval = if u64_to_u256(params.deposit_interval) > storage.default_tune_interval {
            u64_to_u256(params.deposit_interval)
        } else {
            storage.default_tune_interval
        };

        let tmp2 = if params.capacity_in_quote {
            u64_to_u256(params.capacity) * scale / formatted_initial_price
        } else {
            u64_to_u256(params.capacity)
        };

        let metadata_ = BondMetadata {
            last_tune: u64_to_u256(timestamp()),
            last_decay: u64_to_u256(timestamp()),
            length: seconds_to_conclusion,
            deposit_interval: u64_to_u256(params.deposit_interval),
            tune_interval: tune_interval,
            tune_adjustment_delay: storage.default_tune_adjustment,
            debt_decay_interval: debt_decay_interval,
            tune_interval_capacity: tune_interval_capacity,
            tune_below_capacity: u64_to_u256(params.capacity) - tune_interval_capacity,
            last_tune_debt: tmp2 * debt_decay_interval / seconds_to_conclusion,
        };

        storage.metadata.insert(market_id, metadata_);

        // Initial target debt is equal to capacity scaled by the ratio of the debt decay interval and the length of the market.
        // This is the amount of debt that should be decayed over the decay interval if no purchases are made.
        // Note price should be passed in a specific format:
        // price = (payoutPriceCoefficient / quotePriceCoefficient)
        //         * 10**(36 + scaleAdjustment + quoteDecimals - payoutDecimals + payoutPriceDecimals - quotePriceDecimals)
        // See IBondSDA for more details and variable definitions.
        

        let capacity = if params.capacity_in_quote {
            u64_to_u256(params.capacity) * scale / formatted_initial_price
        } else {
            u64_to_u256(params.capacity)
        };

        let target_debt = capacity * debt_decay_interval / seconds_to_conclusion;

        // Max payout is the amount of capacity that should be utilized in a deposit
        // interval. for example, if capacity is 1,000 TOKEN, there are 10 days to conclusion,
        // and the preferred deposit interval is 1 day, max payout would be 100 TOKEN.
        // Additionally, max payout is the maximum amount that a user can receive from a single
        // purchase at that moment in time.
        let max_payout = capacity * u64_to_u256(params.deposit_interval) / seconds_to_conclusion;
        let market = BondMarket {
            owner: addr.into(),
            payout_token: params.payout_token,
            quote_token: params.quote_token, 
            callback_addr: params.callback_addr, 
            capacity_in_quote: params.capacity_in_quote, 
            capacity: u64_to_u256(params.capacity), 
            total_debt: target_debt, 
            min_price: formatted_minimum_price, 
            max_payout: max_payout, 
            sold: U256::min(), 
            purchased: U256::min(), // quote tokens in
            scale: scale, // scaling factor for the market (see MarketParams struct)
        };

        storage.markets.insert(market_id, market);

        // Max debt serves as a circuit breaker for the market. let's say the quote token is a stablecoin,
        // and that stablecoin depegs. without max debt, the market would continue to buy until it runs
        // out of capacity. this is configurable with a 3 decimal buffer (1000 = 1% above initial price).
        // Note that its likely advisable to keep this buffer wide.
        // Note that the buffer is above 100%. i.e. 10% buffer = initial debt * 1.1
        // 1e5 = 100,000. 10,000 / 100,000 = 10%.
        // See IBondSDA.MarketParams for more information on determining a reasonable debt buffer.
        let min_debt_buffer_ = if max_payout * FEE_DECIMALS / target_debt > storage.min_debt_buffer {
            max_payout * FEE_DECIMALS / target_debt
        } else {
            storage.min_debt_buffer
        };
        
        let tmp3 = if u64_to_u256(params.debt_buffer) > storage.min_debt_buffer {
            u64_to_u256(params.debt_buffer)
        } else {
            min_debt_buffer_
        };
        let max_debt = target_debt + target_debt * tmp3 / u64_to_u256(100000);

        // The control variable is set as the ratio of price to the initial targetDebt, scaled to prevent under/overflows.
        // It determines the price of the market as the debt decays and is tuned by the market based on user activity.
        // See _tune() for more information.
        //
        // price = control variable * debt / scale
        // therefore, control variable = price * scale / debt
        // TODO: handle overflow
        let control_variable = formatted_initial_price * scale / target_debt;
        let term = BondTerms {
            control_variable: control_variable,
            max_debt: max_debt,
            vesting: u64_to_u256(params.vesting),
            conclusion: u64_to_u256(params.conclusion),
        };

        storage.terms.insert(market_id, term);

        market_id
    }

    // close a bond market
    #[storage(read, write)]
    fn close_market(market_id: u64){
        let sender = msg_sender().unwrap();
        let addr:Address = match sender {
            Identity::Address(identity) => identity,
            _ => revert(0),
        };
        let mut market = storage.markets.get(market_id).unwrap();
        require(addr.into() == market.owner, VendorError::OnlyMarketOwner);
        let mut term  = storage.terms.get(market_id).unwrap();
        term.conclusion = u64_to_u256(timestamp());
        market.capacity = U256::min();
        storage.markets.insert(market_id, market);
        storage.terms.insert(market_id, term);
    }

    // pay quote tokens for a bond in market
    #[storage(read, write)]
    fn purchase_bond(market_id: u64, amount: u64, min_amount: u64) -> u64{
        let sender = msg_sender().unwrap();
        let addr:ContractId = match sender {
            Identity::ContractId(identity) => identity,
            _ => revert(0),
        };
        require(addr.into() == storage.seller, VendorError::NotAuthorized);

        let mut market = storage.markets.get(market_id).unwrap();
        let mut term  = storage.terms.get(market_id).unwrap();
        let mut meta  = storage.metadata.get(market_id).unwrap();

        // If market uses a callback, check that owner is still callback authorized
        require(market.callback_addr == ZERO_B256 || storage.callback_authorized.get(market.owner).unwrap(), VendorError::NotAuthorized);

        // Markets end at a defined timestamp
        let curr_time = u64_to_u256(timestamp());
        require(curr_time < term.conclusion, VendorError::MarketConcluded);

        // _decayAndGetPrice
        let decayed_debt = current_debt(market_id);
        market.total_debt = decayed_debt;
        let mut adjustment = storage.adjustments.get(market_id).unwrap_or(NO_ADJUSTMENT);
        if (adjustment.active) {
            let (adjust_by, seconds_since, still_active) = control_decay(market_id);
            term.control_variable -= adjust_by;

            if still_active {
                adjustment.change -= adjust_by;
                adjustment.time_to_adjusted -= seconds_since;
                adjustment.last_adjustment = curr_time;
            } else {
                adjustment.active = false;
            }
        }

        let mut price = current_market_price(market_id);
        let min_price = market.min_price;
        if price < min_price {
            price = min_price;
        }

        let payout = u64_to_u256(amount) * market.scale / price;
        let debt_decay_interval = meta.debt_decay_interval;
        let last_tune_debt = meta.last_tune_debt;
        let last_decay = meta.last_decay;

        let last_decay_increment = (debt_decay_interval * payout + last_tune_debt - ONE_U256) / last_tune_debt;
        meta.last_decay += last_decay_increment;

        let decay_offset = if curr_time > last_decay {
            if debt_decay_interval > (curr_time - last_decay) {
                debt_decay_interval - (curr_time - last_decay)
            } else {
                U256::min()
            }
        } else {
            debt_decay_interval + last_decay - curr_time
        };

        market.total_debt = decayed_debt * debt_decay_interval / (decay_offset + last_decay_increment) + payout + ONE_U256;

        // Payout must be greater than user inputted minimum
        require(payout > u64_to_u256(min_amount) || payout == u64_to_u256(min_amount), VendorError::AmountLessThanMinimum);

        // Markets have a max payout amount, capping size because deposits
        // do not experience slippage. max payout is recalculated upon tuning
        require(payout < market.max_payout || payout == market.max_payout, VendorError::MaxPayoutExceeded);

        // Update Capacity and Debt values

        // Capacity is either the number of payout tokens that the market can sell
        // (if capacity in quote is false),
        //
        // or the number of quote tokens that the market can buy
        // (if capacity in quote is true)

        // If amount/payout is greater than capacity remaining, revert
        let tmp_capacity:bool = if market.capacity_in_quote {
            u64_to_u256(amount) > market.capacity
        } else {
            payout > market.capacity
        };

        require(!tmp_capacity, VendorError::NotEnoughCapacity);
        // Capacity is decreased by the deposited or paid amount
        let capacity_offset = if market.capacity_in_quote {
            u64_to_u256(amount)
        } else {
            payout
        };
        market.capacity -= capacity_offset;

        // Markets keep track of how many quote tokens have been
        // purchased, and how many payout tokens have been sold
        market.purchased += u64_to_u256(amount);
        market.sold += payout;

        // Circuit breaker. If max debt is breached, the market is closed
        if (term.max_debt < market.total_debt) {
            term.conclusion = curr_time;
            market.capacity = U256::min();
        } else {
            // If market will continue, the control variable is tuned to to expend remaining capacity over remaining market duration
            let time_remaining = term.conclusion - curr_time;
            let capacity = if market.capacity_in_quote {
                market.capacity * market.scale / price
            } else {
                market.capacity
            };

            let tmp = if market.capacity_in_quote {
                market.purchased * market.scale / price
            } else {
                market.sold
            };
            let init_capacity = capacity + tmp;

            let time_neutral_capacity = init_capacity * (meta.length - time_remaining) / meta.length + capacity;
            if (market.capacity < meta.tune_below_capacity && time_neutral_capacity < init_capacity) || 
               ((curr_time > meta.last_tune + meta.tune_interval || curr_time == meta.last_tune + meta.tune_interval) && time_neutral_capacity > init_capacity) {
                market.max_payout = capacity * meta.deposit_interval / time_remaining;
                let target_debt = time_neutral_capacity * meta.debt_decay_interval / meta.length;
                let control_variable = term.control_variable;
                let new_control_variable = (price * market.scale + target_debt - ONE_U256) / target_debt;
                if (new_control_variable < control_variable) {
                    let change = control_variable - new_control_variable;
                    adjustment.change = change;
                    adjustment.last_adjustment = curr_time;
                    adjustment.time_to_adjusted = meta.tune_adjustment_delay;
                    adjustment.active = true;
                } else {
                    term.control_variable = new_control_variable;
                    adjustment.active = false;
                }

                meta.last_tune = curr_time;
                meta.tune_below_capacity = if market.capacity > meta.tune_interval_capacity {
                    market.capacity - meta.tune_interval_capacity
                } else {
                    U256::min()
                };
                meta.last_tune_debt = target_debt;
            }
        }

        storage.metadata.insert(market_id, meta);
        storage.adjustments.insert(market_id, adjustment);
        storage.terms.insert(market_id, term);
        storage.markets.insert(market_id, market);

        u256_to_u64(payout)
    }

    // set market intervals to different values than the defaults
    #[storage(read, write)]
    fn set_intervals(market_id: u64, intervals: (u64, u64, u64)){
        // Check that the market is live
        require(is_live_(market_id), VendorError::InvalidParams);

        // Check that the intervals are non-zero
        require(intervals.0 != 0 && intervals.1 != 0 && intervals.2 != 0, VendorError::InvalidParams);

        // Check that tuneInterval >= tuneAdjustmentDelay
        require(intervals.0 >= intervals.1, VendorError::InvalidParams);

        let mut meta = storage.metadata.get(market_id).unwrap();
        // Check that tuneInterval >= depositInterval
        require(intervals.0 >= u256_to_u64(meta.deposit_interval), VendorError::InvalidParams);

        // Check that debtDecayInterval >= minDebtDecayInterval
        require(intervals.2 >= u256_to_u64(storage.min_debt_decay_interval), VendorError::InvalidParams);

        // Check that sender is market owner
        let market = storage.markets.get(market_id).unwrap();
        let sender = msg_sender().unwrap();
        let addr:Address = match sender {
            Identity::Address(identity) => identity,
            _ => revert(0),
        };
        require(addr.into() == market.owner, VendorError::OnlyMarketOwner);

        let term = storage.terms.get(market_id).unwrap();
        // Update intervals
        meta.tune_interval = u64_to_u256(intervals.0);
        meta.tune_interval_capacity = market.capacity * u64_to_u256(intervals.0) / (term.conclusion - u64_to_u256(timestamp())); // don't have a stored value for market duration, this will update tuneIntervalCapacity based on time remaining
        let tune_below_capacity_ = if market.capacity > meta.tune_interval_capacity {
            market.capacity - meta.tune_interval_capacity
        } else {
            U256::min()
        };
        meta.tune_interval_capacity = tune_below_capacity_;
        
        meta.tune_adjustment_delay = u64_to_u256(intervals.1);
        meta.debt_decay_interval = u64_to_u256(intervals.2);
        storage.metadata.insert(market_id, meta);
    }

    // designate a new owner of a market
    #[storage(read, write)]
    fn push_ownership(market_id: u64, owner: b256){
        let sender = msg_sender().unwrap();
        let addr:Address = match sender {
            Identity::Address(identity) => identity,
            _ => revert(0),
        };
        let market = storage.markets.get(market_id).unwrap();
        require(addr.into() == market.owner, VendorError::OnlyMarketOwner);
        storage.new_owners.insert(market_id, owner);
    }

    // accept ownership of a market
    #[storage(read, write)]
    fn pull_ownership(market_id: u64){
        let sender = msg_sender().unwrap();
        let addr:Address = match sender {
            Identity::Address(identity) => identity,
            _ => revert(0),
        };
        let mut market = storage.markets.get(market_id).unwrap();
        require(addr.into() == market.owner, VendorError::OnlyMarketOwner);
        market.owner = storage.new_owners.get(market_id).unwrap();
        storage.markets.insert(market_id, market);
    }

    // set vendor defaults
    #[storage(read, write)]
    fn set_defaults(defaults: (u64, u64, u64, u64, u64, u64)){
        // Restricted to authorized addresses

        // Validate inputs
        // Check that defaultTuneInterval >= defaultTuneAdjustment
        require(defaults.0 >= defaults.1, VendorError::InvalidParams);

        // Check that defaultTuneInterval >= minDepositInterval
        require(defaults.0 >= defaults.3, VendorError::InvalidParams);

        // Check that minDepositInterval <= minMarketDuration
        require(defaults.3 <= defaults.4, VendorError::InvalidParams);

        // Check that minDebtDecayInterval >= 5 * minDepositInterval
        require(defaults.2 >= defaults.3 * 5, VendorError::InvalidParams);

        // Update defaults
        
        storage.default_tune_interval = u64_to_u256(defaults.0);
        storage.default_tune_adjustment = u64_to_u256(defaults.1);
        storage.min_debt_decay_interval = u64_to_u256(defaults.2);
        storage.min_deposit_interval = u64_to_u256(defaults.3);
        storage.min_market_duration = u64_to_u256(defaults.4);
        storage.min_debt_buffer = u64_to_u256(defaults.5);
    }

    // provides info for seller to execute purchases on a market
    // TOOD: return multiple items
    #[storage(read)]
    fn get_market_info_for_purchase(id: u64) -> (b256, b256, b256, b256, u64, u64){
        let market = storage.markets.get(id).unwrap();
        let term = storage.terms.get(id).unwrap();
        (
            market.owner,
            market.callback_addr,
            market.payout_token,
            market.quote_token,
            u256_to_u64(term.vesting),
            u256_to_u64(market.max_payout)
        )
    }

    // calculate current market price of payout token in quote tokens
    #[storage(read)]
    fn market_price(id: u64) -> (u64, u64, u64, u64){
        market_price_(id).into()
    }

    // scale value to use when converting between quote token and payout token amounts with market_price()
    #[storage(read)]
    fn market_scale(id: u64) -> (u64, u64, u64, u64){
        let market = storage.markets.get(id).unwrap();
        market.scale.into()
    }

    // payout due for amount of quote tokens
    #[storage(read, write)]
    fn payout_for(id: u64, amount: u64, referrer: b256) -> u64{
        // Calculate the payout for the given amount of tokens
        let seller = abi(Seller, storage.seller);
        let fee = u64_to_u256(amount) * u64_to_u256(seller.get_fee(referrer)) / u64_to_u256(100000);
        let market = storage.markets.get(id).unwrap();
        let payout = (u64_to_u256(amount) - fee) * market.scale / market_price_(id);

        // Check that the payout is less than or equal to the maximum payout,
        // Revert if not, otherwise return the payout
        require(payout < market.max_payout || payout == market.max_payout, VendorError::MaxPayoutExceeded);
        u256_to_u64(payout)
    }

    // returns maximum amount of quote token accepted by market
    #[storage(read)]
    fn max_amount_accepted(id: u64, referrer: b256) -> u64{
        // Calculate maximum amount of quote tokens that correspond to max bond size
        // Maximum of the maxPayout and the remaining capacity converted to quote tokens
        let market = storage.markets.get(id).unwrap();
        let price = market_price_(id);
        let quote_capacity = if market.capacity_in_quote {
            market.capacity
        } else {
            market.capacity * price / market.scale
        };

        let max_quote = market.max_payout * price / market.scale;
        let amount_accepted = if quote_capacity < max_quote {
            quote_capacity
         } else{
            max_quote
         } ;


        // Take into account teller fees and return
        // Estimate fee based on amountAccepted. Fee taken will be slightly larger than
        // this given it will be taken off the larger amount, but this avoids rounding
        // errors with trying to calculate the exact amount.
        // Therefore, the maxAmountAccepted is slightly conservative.
        let seller = abi(Seller, storage.seller);
        let estimated_fee = amount_accepted * u64_to_u256(seller.get_fee(referrer)) / u64_to_u256(100000);

        u256_to_u64(amount_accepted + estimated_fee)
    }

    // check if market sends payout immediately
    #[storage(read)]
    fn is_instant_swap(id: u64)-> bool{
        let term = storage.terms.get(id).unwrap();
        let vesting = term.vesting;
        if vesting < MAX_FIXED_TERM || vesting == MAX_FIXED_TERM{
            vesting == U256::min()
        } else {
            vesting < u64_to_u256(timestamp()) || vesting == u64_to_u256(timestamp())
        }
    }

    // check if market accepts deposits
    #[storage(read)]
    fn is_live(id: u64)->bool{
        is_live_(id)
    }

    // returns seller that serives the market
    // TODO: teller -> seller
    #[storage(read)]
    fn get_seller() -> b256{
        storage.seller
    }

    // get current capacity of a market
    #[storage(read)]
    fn current_capacity(id: u64)->u64{
        let market = storage.markets.get(id).unwrap();
        u256_to_u64(market.capacity)
    }

    // returns address of the market owner
    #[storage(read)]
    fn owner_of(id: u64) -> b256{
        let market = storage.markets.get(id).unwrap();
        market.owner
    }

    // returns floor that services vendor
    // TODO: addgregator -> floor
    #[storage(read)]
    fn get_floor() -> b256{
        storage.floor
    }

}