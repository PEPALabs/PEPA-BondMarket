library seller_abi;

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

// function prototypes
abi Seller{

    // initialize seller
    #[storage(read,write)]
    fn initialize(protocol_: b256, aggregator_: b256, guardian_: b256, authority_: b256);

    // claim fees accrued for input tokens and sends to protocol. Caller must be administrator
    #[storage(read, write)]
    fn claim_fee(tokens: Vec<b256>, to: b256);

    // ‘Create’ function fee discount
    // Amount standard fee is reduced by for partners who just want to use the ‘create’ function to issue bond tokens
    // Configurable by policy
    #[storage(read, write)]
    fn create_fee_discount(discount: u64);

    // get current fee charged by the seller based on the combined protocol and referrer fee
    #[storage(read)]
    fn get_fee(referrer: b256) -> u64;

    // get current fee charged by the seller based on the combined protocol and referrer fee
    // #[storage(read)]
    // fn protocol_fee() -> u64;

    // exchange quote tokens for a bond in a specified market
    #[storage(read, write)]
    fn purchase(recipient: b256, referrer: b256, id: u64, amount: u64, min_amount_out: u64) -> (u64, u64);

    // fee paid to a frontend operator
    // there are some situations where the fees may round down to zero (can happen with big price differences on small decimal tokens)
    // this is purely a theorectical edge case, as the bond amount would not be practical
    #[storage(read, write)]
    fn referrer_fee(fee: u64);

    // set protocol fee
    // must be guardian
    #[storage(read, write)]
    fn set_protocol_fee(fee: u64);

    // set your fee as a referrer to the protocol
    // fee is set for sending address
    #[storage(read, write)]
    fn set_referrer_fee(fee: u64);

    #[storage(read)]
    fn get_owner()->b256;

    #[storage(read)]
    fn balance_of(token: b256)->u64;
}
