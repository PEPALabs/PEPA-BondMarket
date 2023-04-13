library bond_token_abi;

use std::{
    address::*,
    revert::require,
    context::{*},
    contract_id::ContractId,
    address::Address,
    storage::*,
    token::*,
    auth::*,
    call_frames::*,
};



abi BondToken {
    // Initialize contract
    #[storage(read, write)]
    fn initialize(mint_amount: u64, owner: ContractId);
    // get token balance
    #[storage(read)]
    fn get_balance() -> u64;
    // Mint token coins
    #[storage(read, write)]
    fn mint_coins(mint_amount: u64, mint_address: Address);
    // Burn token coins
    #[storage(read,write)]
    fn burn_coins(coins: u64, burn_address: Address);
    // Transfer a contract coins to a given output
    #[storage(read, write)]
    fn transfer_coins(coins: u64, from:Address, to: Address);
    #[storage(read)]
    fn get_mint_amount() -> u64;
}
