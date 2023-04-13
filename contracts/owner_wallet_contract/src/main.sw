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

use owner_wallet_abi::*;

impl OwnerWallet for Contract {
    #[storage(read)]
    fn balance_of(token: b256) -> u64 {
        this_balance(ContractId::from(token))
    }

    #[storage(read, write)]
    fn transfer_token(token: b256, amount: u64, to: Identity) {
        transfer(amount, ContractId::from(token), to);
    }
}
