library vendor_abi;

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

pub enum VendorError {
  PlaceholderError: (),
  NewMarketsNotAllowed: (),
  InvalidParams: (),
  NotAuthorized: (),
  InitialPriceLessThanMin: (),
  OnlyMarketOwner: (),
  MarketConcluded: (),
  AmountLessThanMinimum: (),
  MaxPayoutExceeded: (),
  NotEnoughCapacity: (),
  U256ConvertOverflow: (),
}

pub struct MarketParams {
    payout_token: b256,
    quote_token: b256,
    callback_addr: b256,
    capacity_in_quote: bool,
    capacity: u64,
    formatted_initial_price: (u64, u64, u64),
    formatted_minimum_price: (u64, u64, u64),
    debt_buffer: u64,
    vesting: u64,
    conclusion: u64,
    deposit_interval: u64,
    scale_adjustment: u64,
    scale_adjustment_positive: bool
}

pub struct BondMarket {
    owner: b256, // market owner. sends payout tokens, receives quote tokens (defaults to creator)
    payout_token: b256, // token to pay depositors with
    quote_token: b256, // token to accept as payment
    callback_addr: b256, // address to call for any operations on bond purchase. Must inherit to IBondCallback.
    capacity_in_quote: bool, // capacity limit is in payment token (true) or in payout (false, default)
    capacity: U256, // capacity remaining
    total_debt: U256, // total payout token debt from market
    min_price: U256, // minimum price (hard floor for the market)
    max_payout: U256, // max payout tokens out in one order
    sold: U256, // payout tokens out
    purchased: U256, // quote tokens in
    scale: U256, // scaling factor for the market (see MarketParams struct)
}

pub struct BondTerms {
    control_variable: U256, // scaling variable for price
    max_debt: U256, // max payout token debt accrued
    vesting: U256, // length of time from deposit to expiry if fixed-term, vesting timestamp if fixed-expiry
    conclusion: U256, // timestamp when market no longer offered
}

pub struct BondMetadata {
    last_tune: U256,
    last_decay: U256,
    length: U256,
    deposit_interval: U256,
    tune_interval: U256,
    tune_adjustment_delay: U256,
    debt_decay_interval: U256,
    tune_interval_capacity: U256,
    tune_below_capacity: U256,
    last_tune_debt: U256,
}

pub struct Adjustment {
    change: U256,
    last_adjustment: U256,
    time_to_adjusted: U256, // how long until adjustment happens
    active: bool,
}


// function prototypes
abi Vendor{

    // initialize vendor
    #[storage(read,write)]
    fn initialize(seller_: b256, floor_: b256);

    // create a bond market
    #[storage(read, write)]
    fn create_market(params: MarketParams)->u64;

    // close a bond market
    #[storage(read, write)]
    fn close_market(market_id: u64);

    // pay quote tokens for a bond in market
    #[storage(read, write)]
    fn purchase_bond(market_id: u64, amount: u64, min_amount: u64) -> u64;

    // set market intervals to different values than the defaults
    #[storage(read, write)]
    fn set_intervals(market_id: u64, intervals: (u64, u64, u64));

    // designate a new owner of a market
    #[storage(read, write)]
    fn push_ownership(market_id: u64, owner: b256);

    // accept ownership of a market
    #[storage(read, write)]
    fn pull_ownership(market_id: u64);

    // set vendor defaults
    #[storage(read, write)]
    fn set_defaults(defaults: (u64, u64, u64, u64, u64, u64));

    // provides info for seller to execute purchases on a market
    // TOOD: return multiple items
    #[storage(read)]
    fn get_market_info_for_purchase(id: u64) -> (b256, b256, b256, b256, u64, u64);

    // calculate current market price of payout token in quote tokens
    #[storage(read)]
    fn market_price(id: u64) -> (u64, u64, u64, u64);

    // scale value to use when converting between quote token and payout token amounts with market_price()
    #[storage(read)]
    fn market_scale(id: u64) -> (u64, u64, u64, u64);

    // payout due for amount of quote tokens
    #[storage(read, write)]
    fn payout_for(id: u64, amount: u64, referrer: b256) -> u64;

    // returns maximum amount of quote token accepted by market
    #[storage(read)]
    fn max_amount_accepted(id: u64, referrer: b256) -> u64;

    // check if market sends payout immediately
    #[storage(read)]
    fn is_instant_swap(id: u64)-> bool;

    // check if market accepts deposits
    #[storage(read)]
    fn is_live(id: u64)->bool;

    // returns seller that serives the market
    #[storage(read)]
    fn get_seller() -> b256;

    // get current capacity of a market
    #[storage(read)]
    fn current_capacity(id: u64)->u64;

    // returns address of the market owner
    #[storage(read)]
    fn owner_of(id: u64) -> b256;

    // returns floor that services vendor
    #[storage(read)]
    fn get_floor() -> b256;

}