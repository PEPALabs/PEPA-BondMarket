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

pub enum SellerError {
  PlaceholderError: (),
}

// TODO: fix datatype: u256 -> u64 in Sway
// TODO: fix external view override

// function prototypes
abi Seller{

    // initialize seller
    #[storage(read,write)]
    fn initialize();

    // claim fees accrued for input tokens and sends to protocol. Caller must be administrator
    #[storage(read)]
    fn claim_fee(tokens: [b256], to: b256);

    // ‘Create’ function fee discount
    // Amount standard fee is reduced by for partners who just want to use the ‘create’ function to issue bond tokens
    // Configurable by policy
    #[storage(read, write)]
    fn create_fee_discount(discount: u64);

    // get current fee charged by the seller based on the combined protocol and referrer fee
    #[storage(read)]
    fn get_fee(referrer: b256) -> u64;

    // get current fee charged by the seller based on the combined protocol and referrer fee
    #[storage(read)]
    fn protocol_fee() -> u64;

    // exchange quote tokens for a bond in a specified market
    #[storage(read, write)]
    fn purchase(recipient: b256, referrer: b256, id: b256, amount: u64, min_amount_out: u64) -> [u64, u64];

    // fee paid to a frontend operator
    // there are some situations where the fees may round down to zero (can happen with big price differences on small decimal tokens)
    // this is purely a theorectical edge case, as the bond amount would not be practical
    #[storage(read)]
    fn referrer_fee(referrer: b256) -> u64;

    // fees earned by an address, by token
    #[storage(read)]
    fn rewards(referrer: b256, token: b256) -> u64;

    // set protocol fee
    // must be guardian
    #[storage(read, write)]
    fn set_protocol_fee(fee: u64);

    // set your fee as a referrer to the protocol
    // fee is set for sending address
    #[storage(read, write)]
    fn set_referrer_fee(fee: u64);

}

storage {
    template_root: b256 = ZERO_B256, 
    swap_pair: StorageMap<(b256, b256), b256> = StorageMap {},
    swap_address: StorageMap<b256, bool> = StorageMap {},
}

impl Seller for Contract {

    // initialize seller
    #[storage(read,write)]
    fn initialize();

    // claim fees accrued for input tokens and sends to protocol. Caller must be administrator
    #[storage(read)]
    fn claim_fee(tokens: [b256], to: b256){
        uint256 len = tokens_.length;
        for (uint256 i; i < len; ++i) {
            ERC20 token = tokens_[i];
            uint256 send = rewards[msg.sender][token];

            if (send != 0) {
                rewards[msg.sender][token] = 0;
                token.safeTransfer(to_, send);
            }
        }
    }

    // ‘Create’ function fee discount
    // Amount standard fee is reduced by for partners who just want to use the ‘create’ function to issue bond tokens
    // Configurable by policy
    #[storage(read, write)]
    fn create_fee_discount(discount: u64){
        if (discount_ > protocolFee) revert Teller_InvalidParams();
        createFeeDiscount = discount_;
    }

    // get current fee charged by the seller based on the combined protocol and referrer fee
    #[storage(read)]
    fn get_fee(referrer: b256){
        return protocolFee + referrerFees[referrer_];
    }

    // Q: dupilicate of get_fee()?
    // // get current fee charged by the seller based on the combined protocol and referrer fee
    // #[storage(read)]
    // fn protocol_fee(){
    //     return protocolFee + referrerFees[referrer_];
    // }

    // exchange quote tokens for a bond in a specified market
    #[storage(read, write)]
    fn purchase(recipient: b256, referrer: b256, id: b256, amount: u64, min_amount_out: u64){
        // TODO: assert nonReentrant

        ERC20 payoutToken;
        ERC20 quoteToken;
        uint48 vesting;
        uint256 payout;

        // Calculate fees for purchase
        // 1. Calculate referrer fee
        // 2. Calculate protocol fee as the total expected fee amount minus the referrer fee
        //    to avoid issues with rounding from separate fee calculations
        uint256 toReferrer = amount_.mulDiv(referrerFees[referrer_], FEE_DECIMALS);
        uint256 toProtocol = amount_.mulDiv(protocolFee + referrerFees[referrer_], FEE_DECIMALS) -
            toReferrer;

        {
            IBondAuctioneer auctioneer = _aggregator.getAuctioneer(id_);
            address owner;
            (owner, , payoutToken, quoteToken, vesting, ) = auctioneer.getMarketInfoForPurchase(
                id_
            );

            // Auctioneer handles bond pricing, capacity, and duration
            uint256 amountLessFee = amount_ - toReferrer - toProtocol;
            payout = auctioneer.purchaseBond(id_, amountLessFee, minAmountOut_);
        }

        // Allocate fees to protocol and referrer
        rewards[referrer_][quoteToken] += toReferrer;
        rewards[_protocol][quoteToken] += toProtocol;

        // Transfer quote tokens from sender and ensure enough payout tokens are available
        _handleTransfers(id_, amount_, payout, toReferrer + toProtocol);

        // Handle payout to user (either transfer tokens if instant swap or issue bond token)
        uint48 expiry = _handlePayout(recipient_, payout, payoutToken, vesting);

        emit Bonded(id_, referrer_, amount_, payout);

        return (payout, expiry);
    }

    // fee paid to a frontend operator
    // there are some situations where the fees may round down to zero (can happen with big price differences on small decimal tokens)
    // this is purely a theorectical edge case, as the bond amount would not be practical
    #[storage(read)]
    fn referrer_fee(referrer: b256){
        if (fee_ > 5e3) revert Teller_InvalidParams();
        referrerFees[msg.sender] = fee_;
    }

    // fees earned by an address and token
    // from: claimFees
    #[storage(read)]
    fn rewards(referrer: b256, token: b256){
        uint256 len = tokens_.length;
        for (uint256 i; i < len; ++i) {
            ERC20 token = tokens_[i];
            uint256 send = rewards[msg.sender][token];

            if (send != 0) {
                rewards[msg.sender][token] = 0;
                token.safeTransfer(to_, send);
            }
        }
    }

    // set protocol fee
    // must be guardian
    #[storage(read, write)]
    fn set_protocol_fee(fee: u64){
        if (fee_ > 5e3) revert Teller_InvalidParams();
        protocolFee = fee_;
    }

    // set your fee as a referrer to the protocol
    // fee is set for sending address
    #[storage(read, write)]
    fn set_referrer_fee(fee: u64){
        if (fee_ > 5e3) revert Teller_InvalidParams();
        referrerFees[msg.sender] = fee_;
    }

}