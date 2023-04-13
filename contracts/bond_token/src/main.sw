contract;

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

use bond_token_abi::BondToken;

const ZERO_B256 = 0x0000000000000000000000000000000000000000000000000000000000000000;


storage {
    owner: ContractId = ContractId { value: 0x0000000000000000000000000000000000000000000000000000000000000000 },
    mint_amount: u64 = 0,
    balance: StorageMap<Address, u64> = StorageMap {},
}

enum Error {
    AddressAlreadyMint: (),
    CannotReinitialize: (),
    MintIsClosed: (),
    NotOwner: (),
    InvalidSender: (),
}

#[storage(read)]
fn validate_owner() {
    let sender = match msg_sender().unwrap(){
        Identity::ContractId (value) => value,
        _ => revert(0),
    };
    require(storage.owner == sender, Error::NotOwner);
}
// TODO: Add color
impl BondToken for Contract {
    //////////////////////////////////////
    // Owner methods
    //////////////////////////////////////
    #[storage(read, write)]
    fn initialize(mint_amount: u64, owner: ContractId) {
        require(storage.owner.into() == ZERO_B256, Error::CannotReinitialize);
        storage.owner = owner;
    }

    #[storage(read,write)]
    fn mint_coins(mint_amount: u64, mint_address: Address) {
        validate_owner();
        let receiver_balance = storage.balance.get(mint_address).unwrap_or(0);
        storage.balance.insert(mint_address, receiver_balance + mint_amount);
        storage.mint_amount += mint_amount;
    }

    #[storage(read,write)]
    fn burn_coins(burn_amount: u64, burn_address: Address) {
        validate_owner();
        let balance = storage.balance.get(burn_address).unwrap_or(0);
        require(balance >= burn_amount,"Insufficient Balance");
        storage.balance.insert(burn_address, balance - burn_amount);
    }

    #[storage(read,write)]
    fn transfer_coins(coins: u64, from:Address, to: Address) {
        validate_owner();
        require(storage.balance.get(from).unwrap_or(0) >= coins,"Insufficient Balance");
        storage.balance.insert(from, storage.balance.get(from).unwrap() - coins);
        storage.balance.insert(to, storage.balance.get(to).unwrap_or(0) + coins);
    }

    //////////////////////////////////////
    // Read-Only methods
    //////////////////////////////////////
    #[storage(read)]
    fn get_mint_amount() -> u64 {
        storage.mint_amount
    }
    #[storage(read)]
    fn get_balance() -> u64 {
        let sender = match msg_sender().unwrap() {
            Identity::Address(value) => value,
            _  => revert(0),
        };
        storage.balance.get(sender).unwrap_or(0)
    }
}

