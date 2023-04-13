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

pub enum FloorError {
  PlaceholderError: (),
}

// TODO: fix datatype: u256 -> u64 in Sway
// TODO: fix external view override

// function prototypes
abi Floor{

    // initialize floor
    #[storage(read,write)]
    fn initialize();

    // register a vendor with floor
    #[storage(read, write)]
    fn register_vendor(vendor_id: b256);

    // register a market with floor
    #[storage(read, write)]
    fn register_market(payout_token: b256, quote_token: b256) -> b256;

    // get vendor with market id
    #[storage(read)]
    fn get_vendor(market_id: b256) -> b256;

    // calculate current market price of payout token in the unit of quote tokens
    #[storage(read)]
    fn market_price(market_id: b256) -> u256;

    // scale the value when converting between quote token and payout token with market_price()
    #[storage(read)]
    fn market_scale(market_id: b256) -> u256;

    // payout due amount in quote tokens
    #[storage(read, write)]
    fn payout_for(market_id: b256, amount: u256) -> address;

    // get maximum amount of quote tokens accepted by the market
    #[storage(read)]
    fn max_amount_accepted(market_id: b256, referrer: address) -> u256;

    // check if market sends payout immediately
    #[storage(read)]
    fn is_instant_swap(market_id: b256) -> bool;

    // check if market accepts deposits
    #[storage(read)]
    fn is_live(market_id: b256) -> bool;

    // get an array of active markets within a range
    #[storage(read)]
    fn live_markets_between(first_id: b256, last_id: b256) -> [b256; u256];

    // get an array of active markets for a quote token
    #[storage(read)]
    fn live_markets_for(first_id: b256, is_payout: bool) -> [b256; u256];

    // get an array of active markets for an owner
    #[storage(read)]
    fn live_markets_by(owner: address, first_id: b256, last_id: b256) -> [b256; u256];

    // get an array of active markets for both payout and quote token
    #[storage(read)]
    fn markets_for(payout: b256, quote: b256) -> [b256; u256];

    // find the market that has the highest ratio of payout token for depositing quote token
    #[storage(read)]
    fn find_market_for(payout: b256, quote: b256, amount_in: u256, min_amount_out: u256, max_expiry: u256) -> u256;

    // get seller that services the market
    #[storage(read)]
    fn get_seller(market_id: b256) -> b256;

    // get current capacity of a market
    #[storage(read)]
    fn current_capacity(market_id: b256) -> u256;
}

// TODO: continue modification from here
storage {
    template_root: b256 = ZERO_B256, 
    swap_pair: StorageMap<(b256, b256), b256> = StorageMap {},
    swap_address: StorageMap<b256, bool> = StorageMap {},
}

// TODO: rename auctioneer -> ...
impl Floor for Contract {

    // initialize floor
    #[storage(read,write)]
    fn initialize(){
    }

    // register a vendor with floor
    #[storage(read, write)]
    fn register_vendor(vendor_id: b256){
        // TODO: assert requriesAuth

        // Restricted to authorized addresses

        // Check that the auctioneer is not already registered
        if (_whitelist[address(auctioneer_)])
            revert Aggregator_AlreadyRegistered(address(auctioneer_));

        // Add the auctioneer to the whitelist
        auctioneers.push(auctioneer_);
        _whitelist[address(auctioneer_)] = true;
    }

    // register a market with floor
    #[storage(read, write)]
    fn register_market(payout_token: b256, quote_token: b256) -> b256{

        if (!_whitelist[msg.sender]) revert Aggregator_OnlyAuctioneer();
        if (address(payoutToken_) == address(0) || address(quoteToken_) == address(0))
            revert Aggregator_InvalidParams();
        marketId = marketCounter;
        marketsToAuctioneers[marketId] = IBondAuctioneer(msg.sender);
        marketsForPayout[address(payoutToken_)].push(marketId);
        marketsForQuote[address(quoteToken_)].push(marketId);
        ++marketCounter;
    }

    // get vendor with market id
    #[storage(read)]
    fn get_vendor(market_id: b256) -> b256{
        return marketsToAuctioneers[id_];
    }

    // calculate current market price of payout token in the unit of quote tokens
    #[storage(read)]
    fn market_price(market_id: b256) -> u256{
        IBondAuctioneer auctioneer = marketsToAuctioneers[id_];
        return auctioneer.marketPrice(id_);
    }

    // scale the value when converting between quote token and payout token with market_price()
    #[storage(read)]
    fn market_scale(market_id: b256) -> u256{
        IBondAuctioneer auctioneer = marketsToAuctioneers[id_];
        return auctioneer.marketScale(id_);
    }

    // payout due amount in quote tokens
    #[storage(read, write)]
    fn payout_for(market_id: b256, amount: u256) -> address{
        IBondAuctioneer auctioneer = marketsToAuctioneers[id_];
        return auctioneer.payoutFor(amount_, id_, referrer_);
    }

    // get maximum amount of quote tokens accepted by the market
    #[storage(read)]
    fn max_amount_accepted(market_id: b256, referrer: address) -> u256{
        IBondAuctioneer auctioneer = marketsToAuctioneers[id_];
        return auctioneer.maxAmountAccepted(id_, referrer_);
    }

    // check if market sends payout immediately
    #[storage(read)]
    fn is_instant_swap(market_id: b256) -> bool{
        IBondAuctioneer auctioneer = marketsToAuctioneers[id_];
        return auctioneer.isInstantSwap(id_);
    }

    // check if market accepts deposits
    #[storage(read)]
    fn is_live(market_id: b256) -> bool{
        IBondAuctioneer auctioneer = marketsToAuctioneers[id_];
        return auctioneer.isLive(id_);
    }

    // get an array of active markets within a range
    #[storage(read)]
    fn live_markets_between(first_id: b256, last_id: b256) -> [b256; u256]{
        uint256 count;
        for (uint256 i = firstIndex_; i < lastIndex_; ++i) {
            if (isLive(i)) ++count;
        }

        uint256[] memory ids = new uint256[](count);
        count = 0;
        for (uint256 i = firstIndex_; i < lastIndex_; ++i) {
            if (isLive(i)) {
                ids[count] = i;
                ++count;
            }
        }
        // return an array of ids
        return ids;
    }

    // get an array of active markets for a quote token
    #[storage(read)]
    fn live_markets_for(first_id: b256, is_payout: bool) -> [b256; u256]{
        uint256[] memory mkts;

        mkts = isPayout_ ? marketsForPayout[token_] : marketsForQuote[token_];

        uint256 count;
        uint256 len = mkts.length;

        for (uint256 i; i < len; ++i) {
            if (isLive(mkts[i])) ++count;
        }

        uint256[] memory ids = new uint256[](count);
        count = 0;

        for (uint256 i; i < len; ++i) {
            if (isLive(mkts[i])) {
                ids[count] = mkts[i];
                ++count;
            }
        }

        return ids;
    }

    // get an array of active markets for an owner
    #[storage(read)]
    fn live_markets_by(owner: address, first_id: b256, last_id: b256) -> [b256; u256]{
        uint256 count;
        IBondAuctioneer auctioneer;
        for (uint256 i = firstIndex_; i < lastIndex_; ++i) {
            auctioneer = marketsToAuctioneers[i];
            if (auctioneer.isLive(i) && auctioneer.ownerOf(i) == owner_) {
                ++count;
            }
        }

        uint256[] memory ids = new uint256[](count);
        count = 0;
        for (uint256 j = firstIndex_; j < lastIndex_; ++j) {
            auctioneer = marketsToAuctioneers[j];
            if (auctioneer.isLive(j) && auctioneer.ownerOf(j) == owner_) {
                ids[count] = j;
                ++count;
            }
        }

        return ids;

    }

    // get an array of active markets for both payout and quote token
    #[storage(read)]
    fn markets_for(payout: b256, quote: b256) -> [b256; u256]{
        uint256[] memory forPayout = liveMarketsFor(payout_, true);
        uint256 count;

        ERC20 quoteToken;
        IBondAuctioneer auctioneer;
        uint256 len = forPayout.length;
        for (uint256 i; i < len; ++i) {
            auctioneer = marketsToAuctioneers[forPayout[i]];
            (, , , quoteToken, , ) = auctioneer.getMarketInfoForPurchase(forPayout[i]);
            if (isLive(forPayout[i]) && address(quoteToken) == quote_) ++count;
        }

        uint256[] memory ids = new uint256[](count);
        count = 0;

        for (uint256 i; i < len; ++i) {
            auctioneer = marketsToAuctioneers[forPayout[i]];
            (, , , quoteToken, , ) = auctioneer.getMarketInfoForPurchase(forPayout[i]);
            if (isLive(forPayout[i]) && address(quoteToken) == quote_) {
                ids[count] = forPayout[i];
                ++count;
            }
        }

        return ids;
    }

    // find the market that has the highest ratio of payout token for depositing quote token
    #[storage(read)]
    fn find_market_for(payout: b256, quote: b256, amount_in: u256, min_amount_out: u256, max_expiry: u256) -> u256{
        uint256[] memory ids = marketsFor(payout_, quote_);
        uint256 len = ids.length;
        // uint256[] memory payouts = new uint256[](len);

        uint256 highestOut;
        uint256 id = type(uint256).max; // set to max so an empty set doesn't return 0, the first index
        uint48 vesting;
        uint256 maxPayout;
        IBondAuctioneer auctioneer;
        for (uint256 i; i < len; ++i) {
            auctioneer = marketsToAuctioneers[ids[i]];
            (, , , , vesting, maxPayout) = auctioneer.getMarketInfoForPurchase(ids[i]);

            uint256 expiry = (vesting <= MAX_FIXED_TERM) ? block.timestamp + vesting : vesting;

            if (expiry <= maxExpiry_) {
                if (minAmountOut_ <= maxPayout) {
                    try auctioneer.payoutFor(amountIn_, ids[i], address(0)) returns (
                        uint256 payout
                    ) {
                        if (payout > highestOut && payout >= minAmountOut_) {
                            highestOut = payout;
                            id = ids[i];
                        }
                    } catch {
                        // fail silently and try the next market
                    }
                }
            }
        }

        return id;
    }

    // get seller that services the market
    #[storage(read)]
    fn get_seller(market_id: b256) -> b256{
        IBondAuctioneer auctioneer = marketsToAuctioneers[id_];
        return auctioneer.getTeller();
    }

    // get current capacity of a market
    #[storage(read)]
    fn current_capacity(market_id: b256) -> u256{
        IBondAuctioneer auctioneer = marketsToAuctioneers[id_];
        return auctioneer.currentCapacity(id_);
    }

}