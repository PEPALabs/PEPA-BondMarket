use fuels::{prelude::*, tx::ContractId, types::*};
use std::io;
use std::collections::HashMap;
use std::{thread, time};
use rand::Fill;
use chrono::{Utc, TimeZone, Duration};
use tai64::Tai64;

abigen!(Contract(name = "Vendor", abi = "../vendor_contract/out/debug/vendor_contract-abi.json"),
        Contract(name = "Floor", abi = "../floor_contract/out/debug/floor_contract-abi.json"),
        Contract(name = "Seller", abi = "./out/debug/seller_contract-abi.json"), 
        Contract(name = "Owner", abi = "../owner_wallet_contract/out/debug/owner_wallet_contract-abi.json"));

const ZERO_B256: &str = "0x0000000000000000000000000000000000000000000000000000000000000000";

fn addr_to_b256(addr: &Bech32Address) -> Bits256 {
    let a = *addr.hash();
    Bits256(a)
}

async fn get_contract_instance() -> (Vendor, ContractId, Floor, ContractId, Seller, ContractId, Owner, ContractId, Vec<WalletUnlocked>, AssetId, AssetId) {
    let mut rng = rand::thread_rng();

    let asset_base = AssetConfig {
        id: BASE_ASSET_ID,
        num_coins: 1,
        coin_amount: 1000000000,
    };

    let mut quote_id = AssetId::zeroed();
    quote_id.try_fill(&mut rng);
    let asset_quote = AssetConfig {
        id: quote_id,
        num_coins: 1,
        coin_amount: 1000000000,
    };

    let mut payout_id = AssetId::zeroed();
    payout_id.try_fill(&mut rng);
    let asset_payout = AssetConfig {
        id: payout_id,
        num_coins: 1,
        coin_amount: 1000000000,
    };
    
    let assets = vec![asset_base.clone(), asset_quote.clone(), asset_payout.clone()];

    // Launch a local network and deploy the contract
    let num_wallets = 10;
    let wallet_config = WalletsConfig::new_multiple_assets(num_wallets, assets);
    let wallets = launch_custom_provider_and_get_wallets(wallet_config, None, None).await;

    let deployer = wallets.get(0).unwrap();
    let deployer2 = wallets.get(1).unwrap();
    let user = wallets.get(2).unwrap();

    let vendor_id = Contract::deploy(
        "../vendor_contract/out/debug/vendor_contract.bin",
        &deployer,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "../vendor_contract/out/debug/vendor_contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let vendor_instance = Vendor::new(vendor_id.clone(), deployer.clone());

    let floor_id = Contract::deploy(
        "../floor_contract/out/debug/floor_contract.bin",
        &deployer,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "../floor_contract/out/debug/floor_contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let floor_instance = Floor::new(floor_id.clone(), deployer.clone());

    let owner_id = Contract::deploy(
        "../owner_wallet_contract/out/debug/owner_wallet_contract.bin",
        &deployer,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "../owner_wallet_contract/out/debug/owner_wallet_contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let owner_instance = Owner::new(owner_id.clone(), deployer.clone());

    let seller_id = Contract::deploy(
        "./out/debug/seller_contract.bin",
        &deployer,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./out/debug/seller_contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let seller_instance = Seller::new(seller_id.clone(), deployer.clone());

    let mut w_vec = vec![deployer.clone(), deployer2.clone(), user.clone()];

    (vendor_instance, vendor_id.into(), floor_instance, floor_id.into(), seller_instance, seller_id.into(), owner_instance, owner_id.into(), w_vec, quote_id, payout_id)
}

#[tokio::test]
async fn can_get_contract_id() -> Result<()>{
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_instance, seller_id, owner_instance, owner_id, w_vec, quote_id, payout_id) = get_contract_instance().await;

    // Now you have an instance of your contract you can use to test each function
    Ok(())
}

#[tokio::test]
async fn test_init() -> Result<()>{
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_instance, seller_id, owner_instance, owner_id, w_vec, quote_id, payout_id) = get_contract_instance().await;
    let seller_b256 = Bits256(*seller_id);
    let floor_b256 = Bits256(*floor_id);
    let owner_b256 = Bits256(*owner_id);
    let deployer = w_vec.get(0).unwrap();
    let transfer_quote = deployer
            .force_transfer_to_contract(&Bech32ContractId::from(owner_id), 1000000, quote_id, TxParameters::default())
            .await;
    
    let transfer_payout = deployer
    .force_transfer_to_contract(&Bech32ContractId::from(owner_id), 1000000, payout_id, TxParameters::default())
    .await;
    
    let init = seller_instance.methods().initialize(owner_b256, floor_b256, owner_b256, owner_b256).call().await.unwrap();
    let seller_owner = seller_instance.methods().get_owner().call().await.unwrap();
    assert!(ContractId::new(seller_owner.value.0) == owner_id);

    let fee = seller_instance.methods().get_fee(floor_b256).call().await.unwrap();
    assert!(fee.value == 0);

    Ok(())
}

#[tokio::test]
async fn test_fee() -> Result<()>{
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_instance, seller_id, owner_instance, owner_id, w_vec, quote_id, payout_id) = get_contract_instance().await;
    let seller_b256 = Bits256(*seller_id);
    let floor_b256 = Bits256(*floor_id);
    let owner_b256 = Bits256(*owner_id);
    let deployer = w_vec.get(0).unwrap();
    let transfer_quote = deployer
            .force_transfer_to_contract(&Bech32ContractId::from(owner_id), 1000000, quote_id, TxParameters::default())
            .await;
    
    let transfer_payout = deployer
    .force_transfer_to_contract(&Bech32ContractId::from(owner_id), 1000000, payout_id, TxParameters::default())
    .await;
    
    let init = seller_instance.methods().initialize(owner_b256, floor_b256, owner_b256, owner_b256).call().await.unwrap();
    let set_protocol = seller_instance.methods().set_protocol_fee(1).call().await.unwrap();

    let fee = seller_instance.methods().get_fee(floor_b256).call().await.unwrap();
    assert!(fee.value == 1);

    let set_referrer = seller_instance.methods().set_referrer_fee(10).call().await.unwrap();
    let fee2 = seller_instance.methods().get_fee(Bits256(*deployer.address().hash())).call().await.unwrap();
    assert!(fee2.value == 11);

    Ok(())
}

#[tokio::test]
async fn test_purchase() -> Result<()>{
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_instance, seller_id, owner_instance, owner_id, w_vec, quote_id, payout_id) = get_contract_instance().await;
    let seller_b256 = Bits256(*seller_id);
    let floor_b256 = Bits256(*floor_id);
    let owner_b256 = Bits256(*owner_id);
    let vendor_b256 = Bits256(*vendor_id);
    let deployer = w_vec.get(0).unwrap();
    let deployer_addr = Bits256(*deployer.address().hash());

    let transfer_quote = deployer
            .force_transfer_to_contract(&Bech32ContractId::from(owner_id), 1000000, quote_id, TxParameters::default())
            .await;
    
    let transfer_payout = deployer
    .force_transfer_to_contract(&Bech32ContractId::from(owner_id), 1000000, payout_id, TxParameters::default())
    .await;

    let start_time = u64::from_be_bytes(Tai64::now().to_bytes());
    let param = MarketParams {
        payout_token: Bits256(*payout_id),
        quote_token: Bits256(*quote_id),
        callback_addr: Bits256::from_hex_str(ZERO_B256).unwrap(),
        capacity_in_quote: false,
        capacity: 10000,
        formatted_initial_price: (1,1,18),
        formatted_minimum_price: (1,1,18),
        debt_buffer: 50000,
        vesting: 0,
        conclusion: start_time + 2 * 24 * 3600,
        deposit_interval: 2 * 3600,
        scale_adjustment: 0,
        scale_adjustment_positive: true
    };

    let vendor_init = vendor_instance.methods().initialize(seller_b256, floor_b256).call().await.unwrap();
    let init_floor = floor_instance.methods().initialize(vendor_b256, Identity::Address(Address::new(*deployer.address().hash()))).call().await.unwrap();
    let register = floor_instance.methods().register_vendor(vendor_b256).call().await.unwrap();
    let market_id = vendor_instance.methods().create_market(param).set_contracts(&[&floor_instance]).call().await.unwrap();
    
    let push = vendor_instance.methods().push_ownership(market_id.value, Bits256(*owner_id)).call().await.unwrap();
    let pull = vendor_instance.methods().pull_ownership(market_id.value).call().await.unwrap();

    let init = seller_instance.methods().initialize(owner_b256, floor_b256, owner_b256, owner_b256).call().await.unwrap();
    let set_protocol = seller_instance.methods().set_protocol_fee(1000).call().await.unwrap();
    let set_referrer = seller_instance.methods().set_referrer_fee(1000).call().await.unwrap();

    let user = w_vec.get(1).unwrap();
    let user_addr = Bits256(*user.address().hash());

    let user_transfer_payout = user
    .force_transfer_to_contract(&Bech32ContractId::from(seller_id), 100, quote_id, TxParameters::default())
    .await;

    let purchase = seller_instance.methods().purchase(user_addr, deployer_addr, market_id.value, 100, 90).set_contracts(&[&floor_instance, &vendor_instance, &owner_instance]).append_variable_outputs(2).call().await.unwrap();
    assert!(purchase.value.0 == 98);
    assert!(purchase.value.1 == 0);

    let user_payout_balance = user.get_asset_balance(&payout_id).await.unwrap();
    let user_quote_balance = user.get_asset_balance(&quote_id).await.unwrap();

    assert!(user_payout_balance == 1000000000 + 98);
    assert!(user_quote_balance == 1000000000 - 100);

    Ok(())
}

#[tokio::test]
async fn test_claim_fee() -> Result<()>{
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_instance, seller_id, owner_instance, owner_id, w_vec, quote_id, payout_id) = get_contract_instance().await;
    let seller_b256 = Bits256(*seller_id);
    let floor_b256 = Bits256(*floor_id);
    let owner_b256 = Bits256(*owner_id);
    let vendor_b256 = Bits256(*vendor_id);
    let deployer = w_vec.get(0).unwrap();
    let deployer_addr = Bits256(*deployer.address().hash());
    let referrer = w_vec.get(1).unwrap();
    let referrer_addr = Bits256(*deployer.address().hash());

    let transfer_quote = deployer
            .force_transfer_to_contract(&Bech32ContractId::from(owner_id), 1000000, quote_id, TxParameters::default())
            .await;
    
    let transfer_payout = deployer
    .force_transfer_to_contract(&Bech32ContractId::from(owner_id), 1000000, payout_id, TxParameters::default())
    .await;

    let start_time = u64::from_be_bytes(Tai64::now().to_bytes());
    let param = MarketParams {
        payout_token: Bits256(*payout_id),
        quote_token: Bits256(*quote_id),
        callback_addr: Bits256::from_hex_str(ZERO_B256).unwrap(),
        capacity_in_quote: false,
        capacity: 10000,
        formatted_initial_price: (1,1,18),
        formatted_minimum_price: (1,1,18),
        debt_buffer: 50000,
        vesting: 0,
        conclusion: start_time + 2 * 24 * 3600,
        deposit_interval: 2 * 3600,
        scale_adjustment: 0,
        scale_adjustment_positive: true
    };

    let vendor_init = vendor_instance.methods().initialize(seller_b256, floor_b256).call().await.unwrap();
    let init_floor = floor_instance.methods().initialize(vendor_b256, Identity::Address(Address::new(*deployer.address().hash()))).call().await.unwrap();
    let register = floor_instance.methods().register_vendor(vendor_b256).call().await.unwrap();
    let market_id = vendor_instance.methods().create_market(param).set_contracts(&[&floor_instance]).call().await.unwrap();
    
    let push = vendor_instance.methods().push_ownership(market_id.value, Bits256(*owner_id)).call().await.unwrap();
    let pull = vendor_instance.methods().pull_ownership(market_id.value).call().await.unwrap();

    let init = seller_instance.methods().initialize(owner_b256, floor_b256, owner_b256, owner_b256).call().await.unwrap();
    let set_protocol = seller_instance.methods().set_protocol_fee(1000).call().await.unwrap();
    let set_referrer = seller_instance.methods().set_referrer_fee(1000).call().await.unwrap();

    let user = w_vec.get(1).unwrap();
    let user_addr = Bits256(*user.address().hash());

    let user_transfer_payout = user
    .force_transfer_to_contract(&Bech32ContractId::from(seller_id), 100, quote_id, TxParameters::default())
    .await;

    let purchase = seller_instance.methods().purchase(user_addr, referrer_addr, market_id.value, 100, 90).set_contracts(&[&floor_instance, &vendor_instance, &owner_instance]).append_variable_outputs(2).call().await.unwrap();
    
    let tokens = vec![Bits256(*quote_id)];
    let fee = seller_instance.methods().claim_fee(tokens, deployer_addr).set_contracts(&[&floor_instance, &vendor_instance, &owner_instance]).append_variable_outputs(1).call().await.unwrap();

    let deployer_quote_balance = deployer.get_asset_balance(&quote_id).await.unwrap();
    assert!(deployer_quote_balance == 1000000000 - 1000000 + 1);

    Ok(())
}