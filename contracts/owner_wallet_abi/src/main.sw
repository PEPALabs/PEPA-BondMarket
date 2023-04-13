library owner_wallet_abi;

abi OwnerWallet {
    #[storage(read)]
    fn balance_of(token: b256) -> u64;

    #[storage(read, write)]
    fn transfer_token(token: b256, amount: u64, to: Identity);
}
