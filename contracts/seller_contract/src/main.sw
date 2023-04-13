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

use seller_abi::*;
use floor_abi::*;
use vendor_abi::*;
use owner_wallet_abi::*;
use bond_token_abi::*;

pub enum SellerError {
  PlaceholderError: (),
  Reentrancy: (),
  SellerInvalidParams: (),
  UnsupportedToken: (),
}

const FEE_DECIMALS = 100000; // one percent equals 1000.

storage {
    template_root: b256 = ZERO_B256, 
    referrer_fees: StorageMap<b256, u64> = StorageMap {},
    protocol_fee: u64 = 0,
    create_fee_discount: u64 = 0,
    rewards: StorageMap<(b256, b256), u64> = StorageMap {},
    bond_tokens: StorageMap<(b256,u64), b256> = StorageMap {},
    protocol: b256 = ZERO_B256,
    aggregator: b256 = ZERO_B256,
    owner: b256 = ZERO_B256,
    authority: b256 = ZERO_B256,
    locked: u64 = 1,
}

#[storage(read, write)]
fn handle_transfers(id: u64, amount: u64, payout: u64, fee_paid: u64) -> u64{
    let floor = abi(Floor, storage.aggregator);
    let vendor_addr = floor.get_vendor(id);
    let vendor = abi(Vendor, vendor_addr);
    let (owner, callback_addr, payout_token, quote_token, _, _) = vendor.get_market_info_for_purchase(id);
    let owner_instance = abi(OwnerWallet, owner);

    // Calculate amount net of fees
    let amount_less_fee = amount - fee_paid;

    // Have to transfer to teller first since fee is in quote token
    // Check balance before and after to ensure full amount received, revert if not
    // Handles edge cases like fee-on-transfer tokens (which are not supported)
    let quote_balance = this_balance(ContractId::from(quote_token));

    // TODO: Not possible in sway, need another user contract
    // let sender = msg_sender().unwrap();
    // let 
    // quote_token.safe_transfer_from(msg.sender, address(this), amount_);
    // if (this_balance < quote_balance + amount_)
    //     revert Teller_UnsupportedToken();

    // If callback address supplied, transfer tokens from teller to callback, then execute callback function,
    // and ensure proper amount of tokens transferred in.
    if (callback_addr != ZERO_B256) {
        // TODO: do not support call back currently

        // Send quote token to callback (transferred in first to allow use during callback)
        // quote_token.safe_transfer(callback_addr, amount_less_fee);

        // // Call the callback function to receive payout tokens for payout
        // uint256 payout_balance = payout_token.balance_of(address(this));
        // IBondCallback(callback_addr).callback(id_, amount_less_fee, payout_);

        // // Check to ensure that the callback sent the requested amount of payout tokens back to the teller
        // if (payout_token.balance_of(address(this)) < (payout_balance + payout_))
        //     revert Teller_InvalidCallback();
    } else {
        // If no callback is provided, transfer tokens from market owner to this contract
        // for payout.
        // Check balance before and after to ensure full amount received, revert if not
        // Handles edge cases like fee-on-transfer tokens (which are not supported)
        
        // let payout_balance = payout_token.balance_of(address(this));
        let payout_balance = this_balance(ContractId::from(payout_token));
        // payout_token.safe_transfer_from(owner, address(this), payout_);
        // if (payout_token.balance_of(address(this)) < (payout_balance + payout_))
        //     revert Teller_UnsupportedToken();
        owner_instance.transfer_token(payout_token, amount_less_fee, Identity::ContractId(contract_id()));

        let payout_after = this_balance(ContractId::from(payout_token));
        require(payout_after >= payout_balance + payout, SellerError::UnsupportedToken);

        return payout_after;
    }

    quote_balance
}

// Handle payout bond token to buyer and return vesting time
#[storage(read,write)]
fn handle_payout(recipient: Address, payout: u64, underlying: b256, vesting:u64) -> u64{
    if(vesting > timestamp()) {
        let bond_token = abi(BondToken, underlying);
        bond_token.mint_coins(payout, recipient);
        vesting
    }else {
        transfer(payout, ContractId::from(underlying), Identity::Address(recipient));
        0
    }
}


impl Seller for Contract {

    // initialize seller
    #[storage(read,write)]
    fn initialize(protocol_: b256, aggregator_: b256, guardian_: b256, authority_: b256) {
        storage.owner = guardian_;
        storage.authority = authority_;
        storage.protocol = protocol_;
        storage.aggregator = aggregator_;

        storage.protocol_fee = 0;
        storage.create_fee_discount = 0;
    }

    // claim fees accrued for input tokens and sends to protocol. Caller must be administrator
    #[storage(read, write)]
    fn claim_fee(tokens: Vec<b256>, to: b256){
        let len = tokens.len();
        let mut i = 0;
        while i < len {
            let token = tokens.get(i).unwrap();
            let sender = msg_sender().unwrap();
            let addr:Address = match sender {
                Identity::Address(identity) => identity,
                _ => revert(0),
            };
            let send = storage.rewards.get((addr.into(), token)).unwrap();
            if send != 0 {
                storage.rewards.insert((addr.into(), token), 0);
                transfer(send, ContractId::from(token), Identity::Address(Address::from(to)));
            }

            i += 1;
        }
    }

    // ‘Create’ function fee discount
    // Amount standard fee is reduced by for partners who just want to use the ‘create’ function to issue bond tokens
    // Configurable by policy
    #[storage(read, write)]
    fn create_fee_discount(discount: u64){
        require(discount <= storage.protocol_fee, SellerError::SellerInvalidParams);
        storage.create_fee_discount = discount;
    }

    // get current fee charged by the seller based on the combined protocol and referrer fee
    #[storage(read)]
    fn get_fee(referrer: b256) -> u64{
        return storage.protocol_fee + storage.referrer_fees.get(referrer).unwrap_or(0);
    }

    // Q: dupilicate of get_fee()?
    // // get current fee charged by the seller based on the combined protocol and referrer fee
    // #[storage(read)]
    // fn protocol_fee(){
    //     return protocolFee + referrerFees[referrer_];
    // }

    // exchange quote tokens for a bond in a specified market
    #[storage(read, write)]
    fn purchase(recipient: b256, referrer: b256, id: u64, amount: u64, min_amount_out: u64) -> (u64, u64){
        // TODO: assert nonReentrant
        require(storage.locked == 1, SellerError::Reentrancy);
        storage.locked = 2;

        // ERC20 payoutToken;
        // ERC20 quoteToken;
        // uint48 vesting;
        // uint256 payout;

        // Calculate fees for purchase
        // 1. Calculate referrer fee
        // 2. Calculate protocol fee as the total expected fee amount minus the referrer fee
        //    to avoid issues with rounding from separate fee calculations
        let to_referrer = amount * storage.referrer_fees.get(referrer).unwrap_or(0) / FEE_DECIMALS;
        let to_protocol = amount * (storage.protocol_fee + storage.referrer_fees.get(referrer).unwrap_or(0)) / FEE_DECIMALS - to_referrer;

        let floor = abi(Floor, storage.aggregator);
        let vendor_addr = floor.get_vendor(id);
        let vendor = abi(Vendor, vendor_addr);
        let (owner, _, payout_token, quote_token, vesting, _) = vendor.get_market_info_for_purchase(
            id
        );

        // // Auctioneer handles bond pricing, capacity, and duration
        let amount_less_fee = amount - to_referrer - to_protocol;
        let payout = vendor.purchase_bond(id, amount_less_fee, min_amount_out);

        // Allocate fees to protocol and referrer
        let referrer_reward = storage.rewards.get((referrer, quote_token)).unwrap_or(0);
        let protocol_reward = storage.rewards.get((storage.protocol, quote_token)).unwrap_or(0);
        storage.rewards.insert((referrer, quote_token), referrer_reward + to_referrer);
        storage.rewards.insert((storage.protocol, quote_token), protocol_reward + to_protocol);

        // Transfer quote tokens from sender and ensure enough payout tokens are available
        let a = handle_transfers(id, amount, payout, to_referrer + to_protocol);

        // // Handle payout to user (either transfer tokens if instant swap or issue bond token)
        // let expiry = vesting;
        let mut expiry = 0;
        if vesting > timestamp() {
            expiry = vesting;
            mint_to(payout, Identity::Address(Address::from(recipient)));
        } else {
            expiry = 0;
            transfer(payout, ContractId::from(payout_token), Identity::Address(Address::from(recipient)));
        }

        storage.locked = 1;

        // return (payout, expiry);
        (payout, expiry)
    }

    // fee paid to a frontend operator
    // there are some situations where the fees may round down to zero (can happen with big price differences on small decimal tokens)
    // this is purely a theorectical edge case, as the bond amount would not be practical
    #[storage(read, write)]
    fn referrer_fee(fee: u64){
        require(storage.locked == 1, SellerError::Reentrancy);
        storage.locked = 2;
        require(fee <= 5000, SellerError::SellerInvalidParams);
        let sender = msg_sender().unwrap();
        let addr:Address = match sender {
            Identity::Address(identity) => identity,
            _ => revert(0),
        };
        storage.referrer_fees.insert(addr.into(), fee);
        storage.locked = 1;
    }

    // set protocol fee
    // must be guardian
    #[storage(read, write)]
    fn set_protocol_fee(fee: u64){
        require(fee <= 5000, SellerError::SellerInvalidParams);
        storage.protocol_fee = fee;
    }

    // set your fee as a referrer to the protocol
    // fee is set for sending address
    #[storage(read, write)]
    fn set_referrer_fee(fee: u64){
        require(storage.locked == 1, SellerError::Reentrancy);
        storage.locked = 2;
        require(fee <= 5000, SellerError::SellerInvalidParams);
        let sender = msg_sender().unwrap();
        let addr:Address = match sender {
            Identity::Address(identity) => identity,
            _ => revert(0),
        };
        storage.referrer_fees.insert(addr.into(), fee);
        storage.locked = 1;
    }

    #[storage(read)]
    fn get_owner()->b256 {
        storage.owner
    }

    #[storage(read)]
    fn balance_of(token: b256)->u64 {
        this_balance(ContractId::from(token))
    }
}