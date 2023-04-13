library floor_abi;

use std::{
    auth::*,
    address::Address,
    assert::assert,
    block::*,
    context::*,
    contract_id::*,
    constants::ZERO_B256,
    external::bytecode_root,
    hash::*,
    result::*,
    revert::revert,
    storage::*,
    token::*,
    u256::U256,
    call_frames::*,
    //auth::*,
    //call_frames::{contract_id, msg_asset_id},,
};

// TODO: vendor payout may need to return u256

// function prototypes
abi Floor{

    // initialize floor
    #[storage(read,write)]
    fn initialize(template_root:b256, owner: Identity);

    // transfer storage owner
    #[storage(read,write)]
    fn transfer_owner(new_owner:Identity);

    // register a vendor with floor
    #[storage(read, write)]
    fn register_vendor(vendor_id: b256);

    // register a market with floor
    #[storage(read, write)]
    fn register_market(payout_token: b256, quote_token: b256) -> u64;

    // get vendor with market id
    #[storage(read)]
    fn get_vendor(market_id: u64) -> b256;

    // calculate current market price of payout token in the unit of quote tokens
    #[storage(read)]
    fn market_price(market_id: u64) -> (u64, u64, u64, u64);

    // scale the value when converting between quote token and payout token with market_price()
    #[storage(read)]
    fn market_scale(market_id: u64) -> (u64, u64, u64, u64);

    // payout due amount in quote tokens
    #[storage(read, write)]
    fn payout_for(market_id: u64, amount: u64, referrer: b256) -> u64;

    // get maximum amount of quote tokens accepted by the market
    #[storage(read)]
    fn max_amount_accepted(market_id: u64, referrer: b256) -> u64;

    // check if market sends payout immediately
    #[storage(read)]
    fn is_instant_swap(market_id: u64) -> bool;

    // check if market accepts deposits
    #[storage(read)]
    fn is_live(market_id: u64) -> bool;

    // get an array of active markets within a range
    #[storage(read)]
    fn next_live_markets_between(first_id: u64, last_id: u64) -> u64;

    // get an array of active markets for a quote token
    #[storage(read)]
    fn next_live_markets_for(first_id: b256, is_payout: bool, start: u64) -> u64;

    // get an array of active markets for an owner
    #[storage(read)]
    fn next_live_markets_by(owner: b256, first_id: b256, last_id: b256, start: u64) -> u64;

    // get an array of active markets for both payout and quote token
    #[storage(read)]
    fn next_markets_for(payout: b256, quote: b256, start: u64) -> u64;

    // find the market that has the highest ratio of payout token for depositing quote token
    #[storage(read)]
    fn find_market_for(payout: b256, quote: b256, amount_in: u64, min_amount_out: u64, max_expiry: u64) -> u64;

    // get seller that services the market
    #[storage(read)]
    fn get_seller(market_id: u64) -> b256;

    // get current capacity of a market
    #[storage(read)]
    fn current_capacity(market_id: u64) -> u64;
}