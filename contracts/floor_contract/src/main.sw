contract;

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

use floor_abi::*;
use vendor_abi::*;

const MAX_FIXED_TERM = 1572480000;

pub enum FloorError {
  UnintializedError:(),
  ReinitailizeError:(),
  PlaceholderError: (),
  AlreadyRegistered: (),
  OnlyVendor: (),
  InvalidParams: (),
  PayoutOverFlow: (),
  QuoteOverFlow: (),
  OnlyOwner: (),
}

// TODO: fix datatype: u256 -> u64 in Sway
// TODO: fix external view override

// TODO: continue modification from here
storage {
    template_root: b256 = ZERO_B256, 
    market_counter: u64 = 0,
    vendors: StorageMap<b256, bool> = StorageMap {},
    whitelist: StorageMap<b256, bool> = StorageMap {},
    markets_to_vendors: StorageMap<u64, b256> = StorageMap {},
    markets_for_payout: StorageMap<(b256, u64), u64> = StorageMap {},
    markets_for_quote: StorageMap<(b256, u64), u64> = StorageMap {},
    payout_idxs: StorageMap<b256, u64> = StorageMap {},
    quote_idxs: StorageMap<b256, u64> = StorageMap {},

    // Authorization
    owner: Option<Identity> = Option::None,
    
}

#[storage(read)]
fn is_live_(market_id: u64) -> bool{
    let vendor = abi(Vendor, storage.markets_to_vendors.get(market_id).unwrap());
    vendor.is_live(market_id)
}

#[storage(read)]
fn next_markets_for_(payout: b256, quote: b256, start: u64) -> u64{
    let mut i = start;
    let len = storage.market_counter;
    while i < len {
        let next_pay_for = next_live_markets_for_(payout, true, i);
        if (i < u64::max()) {
            let vendor_addr = storage.markets_to_vendors.get(next_pay_for).unwrap_or(ZERO_B256);
            if vendor_addr != ZERO_B256 {
                let vendor = abi(Vendor, vendor_addr);
                let (_, _, _, quote_token, _, _) = vendor.get_market_info_for_purchase(next_pay_for);
                if is_live_(next_pay_for) && quote_token == quote {
                    return next_pay_for;
                }
            }
            i = next_pay_for + 1;
        } else {
            i = u64::max();
        }
    }

    u64::max()
}

#[storage(read)]
fn next_live_markets_for_(token: b256, is_payout: bool, start: u64) -> u64{
    let len = if is_payout {
        storage.payout_idxs.get(token).unwrap()
    } else {
        storage.quote_idxs.get(token).unwrap()
    };

    let mut i = start;
    while i < len {
        if is_payout {
            if is_live_(storage.markets_for_payout.get((token, i)).unwrap()) {
                return i;
            }
        } else {
            if is_live_(storage.markets_for_quote.get((token, i)).unwrap()) {
                return i;
            }
        }
        i += 1;
    }
    u64::max()
}

impl Floor for Contract {

    //TODO: Hook vendor initialization
    // initialize floor
    #[storage(read,write)]
    fn initialize(template_root:b256,owner:Identity){
        require(storage.template_root == ZERO_B256, FloorError::ReinitailizeError);
        let root = bytecode_root(ContractId::from(template_root));
        let sender = msg_sender().unwrap();
        storage.template_root = root;

        // set owner
        storage.owner = Option::Some(owner);
    }

    #[storage(read,write)]
    fn transfer_owner(new_owner:Identity){
        require(storage.template_root != ZERO_B256, FloorError::UnintializedError);
        require(msg_sender().unwrap() == storage.owner.unwrap(), FloorError::OnlyOwner);
        storage.owner = Option::Some(new_owner);
    }

    // register a vendor with floor
    #[storage(read, write)]
    fn register_vendor(vendor_id: b256){
        require(storage.template_root != ZERO_B256, FloorError::UnintializedError);
        let sender = msg_sender().unwrap();
        require(sender == storage.owner.unwrap(), FloorError::OnlyOwner);

        // Restricted to authorized addresses

        // Check that the vendor is not already registered
        require(!storage.whitelist.get(vendor_id).unwrap_or(false), FloorError::AlreadyRegistered);
            
        // Add the vendor to the whitelist
        storage.vendors.insert(vendor_id, true);
        storage.whitelist.insert(vendor_id, true);
    }

    // register a market with floor
    #[storage(read, write)]
    fn register_market(payout_token: b256, quote_token: b256) -> u64{
        require(storage.template_root != ZERO_B256, FloorError::UnintializedError);
        let sender = msg_sender().unwrap();
        
        // Restrict to authorized vendors
        let addr:ContractId = match sender {
            Identity::ContractId(identity) => identity,
            _ => revert(0),
        };
        
        require(storage.whitelist.get(addr.into()).unwrap_or(false), FloorError::OnlyVendor);
        require(!(payout_token == ZERO_B256 || quote_token == ZERO_B256), FloorError::InvalidParams);
        let market_id = storage.market_counter;
        storage.markets_to_vendors.insert(market_id, addr.into());
        let payout_idx = storage.payout_idxs.get(payout_token).unwrap_or(0);
        let quote_idx = storage.quote_idxs.get(quote_token).unwrap_or(0);

        let mut payout = storage.markets_for_payout.get((payout_token, payout_idx));
        require(payout.is_none(), FloorError::PayoutOverFlow);
        let mut quote = storage.markets_for_payout.get((quote_token, quote_idx));
        require(quote.is_none(), FloorError::QuoteOverFlow);
        
        storage.markets_for_payout.insert((payout_token, payout_idx), market_id);
        storage.markets_for_quote.insert((quote_token, quote_idx), market_id);
        storage.payout_idxs.insert(payout_token, payout_idx + 1);
        storage.quote_idxs.insert(quote_token, quote_idx + 1);
        storage.market_counter = storage.market_counter + 1;
        market_id
    }

    // get vendor with market id
    #[storage(read)]
    fn get_vendor(market_id: u64) -> b256{
        storage.markets_to_vendors.get(market_id).unwrap_or(ZERO_B256)
    }

    // calculate current market price of payout token in the unit of quote tokens
    #[storage(read)]
    fn market_price(market_id: u64) -> (u64, u64, u64, u64){
        let vendor = abi(Vendor, storage.markets_to_vendors.get(market_id).unwrap());
        vendor.market_price(market_id)
    }

    // scale the value when converting between quote token and payout token with market_price()
    #[storage(read)]
    fn market_scale(market_id: u64) -> (u64, u64, u64, u64){
        let vendor = abi(Vendor, storage.markets_to_vendors.get(market_id).unwrap());
        vendor.market_scale(market_id)
    }

    // payout due amount in quote tokens
    #[storage(read, write)]
    fn payout_for(market_id: u64, amount: u64, referrer: b256) -> u64{
        require(storage.template_root != ZERO_B256, FloorError::UnintializedError);
        let vendor = abi(Vendor, storage.markets_to_vendors.get(market_id).unwrap());
        vendor.payout_for(market_id, amount, referrer)
    }

    // get maximum amount of quote tokens accepted by the market
    #[storage(read)]
    fn max_amount_accepted(market_id: u64, referrer: b256) -> u64{
        let vendor = abi(Vendor, storage.markets_to_vendors.get(market_id).unwrap());
        vendor.max_amount_accepted(market_id, referrer)
    }

    // check if market sends payout immediately
    #[storage(read)]
    fn is_instant_swap(market_id: u64) -> bool{
        let vendor = abi(Vendor, storage.markets_to_vendors.get(market_id).unwrap());
        vendor.is_instant_swap(market_id)
    }

    // check if market accepts deposits
    #[storage(read)]
    fn is_live(market_id: u64) -> bool{
        is_live_(market_id)
    }

    // get an array of active markets within a range
    #[storage(read)]
    fn next_live_markets_between(first_id: u64, last_id: u64) -> u64{
        let mut i = first_id;
        while (i < last_id) {
            if (is_live_(i)) {
                return i;
            }
            i = i + 1;
        }

        i
    }

    // get an array of active markets for a quote token
    #[storage(read)]
    fn next_live_markets_for(token: b256, is_payout: bool, start: u64) -> u64{
        let len = if is_payout {
            storage.payout_idxs.get(token).unwrap()
        } else {
            storage.quote_idxs.get(token).unwrap()
        };

        let mut i = start;
        while i < len {
            if is_payout {
                if is_live_(storage.markets_for_payout.get((token, i)).unwrap()) {
                    return i;
                }
            } else {
                if is_live_(storage.markets_for_quote.get((token, i)).unwrap()) {
                    return i;
                }
            }
            
            i += 1;
        }

        u64::max()
    }

    // get an array of active markets for an owner
    #[storage(read)]
    fn next_live_markets_by(owner: b256, first_id: b256, last_id: b256, start: u64) -> u64{
        let mut i = start;
        let len = storage.market_counter;
        while i < len {
            let vendor_addr = storage.markets_to_vendors.get(i).unwrap_or(ZERO_B256);
            if vendor_addr != ZERO_B256 {
                let vendor = abi(Vendor, vendor_addr);
                if vendor.is_live(i) && vendor.owner_of(i) == owner {
                    return i;
                }
            }
             i += 1;
        }

        u64::max()
    }

    // get an array of active markets for both payout and quote token
    #[storage(read)]
    fn next_markets_for(payout: b256, quote: b256, start: u64) -> u64{
        let mut i = start;
        let len = storage.market_counter;
        while i < len {
            let next_pay_for = next_live_markets_for_(payout, true, i);
            if (i < u64::max()) {
                let vendor_addr = storage.markets_to_vendors.get(next_pay_for).unwrap_or(ZERO_B256);
                if vendor_addr != ZERO_B256 {
                    let vendor = abi(Vendor, vendor_addr);
                    let (_, _, _, quote_token, _, _) = vendor.get_market_info_for_purchase(next_pay_for);
                    if is_live_(next_pay_for) && quote_token == quote {
                        return next_pay_for;
                    }
                }
                i = next_pay_for + 1;
            } else {
                i = u64::max();
            }
        }

        u64::max()
    }

    // find the market that has the highest ratio of payout token for depositing quote token
    #[storage(read)]
    fn find_market_for(payout: b256, quote: b256, amount_in: u64, min_amount_out: u64, max_expiry: u64) -> u64{
        let mut i = 0;
        let mut id:u64 = next_markets_for_(payout, quote, i);
        let mut highest_out = 0;
        let mut vesting = 0;
        let mut max_payout = 0;
        let mut ret = id;

        while id < u64::max() {
            let vendor_addr = storage.markets_to_vendors.get(id).unwrap_or(ZERO_B256);
            if vendor_addr != ZERO_B256 {
                let vendor = abi(Vendor, vendor_addr);
                let (_, _, _, _, vesting, max_payout) = vendor.get_market_info_for_purchase(id);
                let expiry = if vesting <= MAX_FIXED_TERM {
                    timestamp() + vesting
                } else {
                    vesting
                };

                if expiry <= max_expiry {
                    if min_amount_out <= max_payout {
                        let payout_ = vendor.payout_for(amount_in, id, ZERO_B256);
                        if payout_ > highest_out && payout_ >= min_amount_out {
                            highest_out = payout_;
                            ret = id;
                        }
                    }
                }
            }

            id = next_markets_for_(payout, quote, id + 1);
        }

        ret
    }

    // get seller that services the market
    #[storage(read)]
    fn get_seller(market_id: u64) -> b256{
        let vendor_addr = storage.markets_to_vendors.get(market_id).unwrap();
        let vendor = abi(Vendor, vendor_addr);
        vendor.get_seller()
    }

    // get current capacity of a market
    #[storage(read)]
    fn current_capacity(market_id: u64) -> u64{
        let vendor_addr = storage.markets_to_vendors.get(market_id).unwrap();
        let vendor = abi(Vendor, vendor_addr);
        vendor.current_capacity(market_id)
    }

}