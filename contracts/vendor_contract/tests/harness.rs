use fuels::{prelude::*, tx::ContractId, types::*};
use std::io;
use std::collections::HashMap;
use std::{thread, time};
use rand::Fill;
use chrono::{Utc, TimeZone, Duration};
use tai64::Tai64;

// Load abi from json
abigen!(Contract(name = "Vendor", abi = "./out/debug/vendor_contract-abi.json"),
        Contract(name = "Floor", abi = "../floor_contract/out/debug/floor_contract-abi.json"),
        Contract(name = "Seller", abi = "../seller_contract/out/debug/seller_contract-abi.json"));

const ZERO_B256: &str = "0x0000000000000000000000000000000000000000000000000000000000000000";

fn addr_to_b256(addr: &Bech32Address) -> Bits256 {
    let a = *addr.hash();
    Bits256(a)
}

async fn get_contract_instance() -> (Vendor, ContractId, Floor, ContractId, Seller, ContractId, Vec<WalletUnlocked>, AssetId, AssetId) {
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

    let vendor_id = Contract::deploy(
        "./out/debug/vendor_contract.bin",
        &deployer,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./out/debug/vendor_contract-storage_slots.json".to_string(),
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

    let seller_id = Contract::deploy(
        "../seller_contract/out/debug/seller_contract.bin",
        &deployer,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "../seller_contract/out/debug/seller_contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let seller_instance = Seller::new(seller_id.clone(), deployer.clone());

    let mut w_vec = vec![deployer.clone(), deployer2.clone()];

    (vendor_instance, vendor_id.into(), floor_instance, floor_id.into(), seller_instance, seller_id.into(), w_vec, quote_id, payout_id)
}

#[tokio::test]
async fn can_get_contract_id() -> Result<()>{
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_contract, seller_id, w_vec, quote_id, payout_id) = get_contract_instance().await;

    // Now you have an instance of your contract you can use to test each function
    Ok(())
}

#[tokio::test]
async fn test_init() -> Result<()>{
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_contract, seller_id, w_vec, quote_id, payout_id) = get_contract_instance().await;
    let seller_b256 = Bits256(*seller_id);
    let floor_b256 = Bits256(*floor_id);
    
    let init = vendor_instance.methods().initialize(seller_b256, floor_b256).call().await.unwrap();
    let seller = vendor_instance.methods().get_seller().call().await.unwrap();
    let floor = vendor_instance.methods().get_floor().call().await.unwrap();

    assert!(ContractId::new(seller.value.0) == seller_id);
    assert!(ContractId::new(floor.value.0) == floor_id);

    // Now you have an instance of your contract you can use to test each function
    Ok(())
}

#[tokio::test]
async fn test_create_market() -> Result<()> {
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_instance, seller_id, wallets, quote_id, payout_id) = get_contract_instance().await;

    let start_time = u64::from_be_bytes(Tai64::now().to_bytes());
    let param = MarketParams {
        payout_token: Bits256(*payout_id),
        quote_token: Bits256(*quote_id),
        callback_addr: Bits256::from_hex_str(ZERO_B256).unwrap(),
        capacity_in_quote: false,
        capacity: 100,
        formatted_initial_price: (1,1,18),
        formatted_minimum_price: (1,1,18),
        debt_buffer: 50000,
        vesting: 0,
        conclusion: start_time + 2 * 24 * 3600,
        deposit_interval: 2 * 3600,
        scale_adjustment: 0,
        scale_adjustment_positive: true
    };
    let seller_b256 = Bits256(*seller_id);
    let floor_b256 = Bits256(*floor_id);
    let vendor_b256 = Bits256(*vendor_id);
    let deployer = wallets.get(0).unwrap();

    let init = vendor_instance.methods().initialize(seller_b256, floor_b256).call().await.unwrap();
    let init_floor = floor_instance.methods().initialize(vendor_b256, Identity::Address(Address::new(*deployer.address().hash()))).call().await.unwrap();
    let register = floor_instance.methods().register_vendor(vendor_b256).call().await.unwrap();
    let market_id = vendor_instance.methods().create_market(param).set_contracts(&[&floor_instance]).call().await.unwrap();

    let market = vendor_instance.methods().get_market_info_for_purchase(market_id.value).call().await.unwrap();

    assert!(ContractId::new(market.value.0.0) == ContractId::new(*deployer.address().hash()));
    assert!(ContractId::new(market.value.2.0) == ContractId::new(*payout_id));
    assert!(ContractId::new(market.value.3.0) == ContractId::new(*quote_id));
    assert!(market.value.4 == 0);
    assert!(market.value.5 == 4);

    let instant_swap = vendor_instance.methods().is_instant_swap(market_id.value).call().await.unwrap();
    assert!(instant_swap.value == true);

    let capacity = vendor_instance.methods().current_capacity(market_id.value).call().await.unwrap();
    assert!(capacity.value == 100);

    let scale = vendor_instance.methods().market_scale(market_id.value).call().await.unwrap();
    assert!(scale.value == (0,0,0,1000000000000000000));

    let price = vendor_instance.methods().market_price(market_id.value).call().await.unwrap();
    assert!(price.value == (0,0,0,1000000000000000000));

    let amount = vendor_instance.methods().max_amount_accepted(market_id.value, Bits256(*deployer.address().hash())).set_contracts(&[&seller_instance]).call().await.unwrap();
    assert!(amount.value == 4);

    Ok(())
}

#[tokio::test]
async fn test_change_ownership() -> Result<()> {
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_contract, seller_id, wallets, quote_id, payout_id) = get_contract_instance().await;

    let start_time = u64::from_be_bytes(Tai64::now().to_bytes());
    let param = MarketParams {
        payout_token: Bits256(*payout_id),
        quote_token: Bits256(*quote_id),
        callback_addr: Bits256::from_hex_str(ZERO_B256).unwrap(),
        capacity_in_quote: false,
        capacity: 100,
        formatted_initial_price: (1,1,36),
        formatted_minimum_price: (1,1,36),
        debt_buffer: 50000,
        vesting: 0,
        conclusion: start_time + 2 * 24 * 3600,
        deposit_interval: 2 * 3600,
        scale_adjustment: 0,
        scale_adjustment_positive: true
    };
    let seller_b256 = Bits256(*seller_id);
    let floor_b256 = Bits256(*floor_id);
    let vendor_b256 = Bits256(*vendor_id);
    let deployer = wallets.get(0).unwrap();

    let init = vendor_instance.methods().initialize(seller_b256, floor_b256).call().await.unwrap();
    let init_floor = floor_instance.methods().initialize(vendor_b256, Identity::Address(Address::new(*deployer.address().hash()))).call().await.unwrap();
    let register = floor_instance.methods().register_vendor(vendor_b256).call().await.unwrap();
    let market_id = vendor_instance.methods().create_market(param).set_contracts(&[&floor_instance]).call().await.unwrap();

    let deployer2 = wallets.get(1).unwrap();

    let push = vendor_instance.methods().push_ownership(market_id.value, Bits256(*deployer2.address().hash())).call().await.unwrap();
    let pull = vendor_instance.methods().pull_ownership(market_id.value).call().await.unwrap();

    let market = vendor_instance.methods().get_market_info_for_purchase(market_id.value).call().await.unwrap();
    assert!(ContractId::new(market.value.0.0) == ContractId::new(*deployer2.address().hash()));



    Ok(())
}

#[tokio::test]
async fn test_close_market() -> Result<()> {
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_contract, seller_id, wallets, quote_id, payout_id) = get_contract_instance().await;

    let start_time = u64::from_be_bytes(Tai64::now().to_bytes());
    let param = MarketParams {
        payout_token: Bits256(*payout_id),
        quote_token: Bits256(*quote_id),
        callback_addr: Bits256::from_hex_str(ZERO_B256).unwrap(),
        capacity_in_quote: false,
        capacity: 100,
        formatted_initial_price: (1,1,36),
        formatted_minimum_price: (1,1,36),
        debt_buffer: 50000,
        vesting: 0,
        conclusion: start_time + 2 * 24 * 3600,
        deposit_interval: 2 * 3600,
        scale_adjustment: 0,
        scale_adjustment_positive: true
    };
    let seller_b256 = Bits256(*seller_id);
    let floor_b256 = Bits256(*floor_id);
    let vendor_b256 = Bits256(*vendor_id);
    let deployer = wallets.get(0).unwrap();

    let init = vendor_instance.methods().initialize(seller_b256, floor_b256).call().await.unwrap();
    let init_floor = floor_instance.methods().initialize(vendor_b256, Identity::Address(Address::new(*deployer.address().hash()))).call().await.unwrap();
    let register = floor_instance.methods().register_vendor(vendor_b256).call().await.unwrap();
    let market_id = vendor_instance.methods().create_market(param).set_contracts(&[&floor_instance]).call().await.unwrap();

    let alive = vendor_instance.methods().is_live(market_id.value).call().await.unwrap();
    assert!(alive.value == true);

    let close = vendor_instance.methods().close_market(market_id.value).call().await.unwrap();
    let still_alive = vendor_instance.methods().is_live(market_id.value).call().await.unwrap();
    assert!(still_alive.value == false);
    
    Ok(())
}

#[tokio::test]
async fn test_purchase_bond() -> Result<()> {
    let (vendor_instance, vendor_id, floor_instance, floor_id, seller_contract, seller_id, wallets, quote_id, payout_id) = get_contract_instance().await;

    let start_time = u64::from_be_bytes(Tai64::now().to_bytes());
    let param = MarketParams {
        payout_token: Bits256(*payout_id),
        quote_token: Bits256(*quote_id),
        callback_addr: Bits256::from_hex_str(ZERO_B256).unwrap(),
        capacity_in_quote: false,
        capacity: 100,
        formatted_initial_price: (1,1,36),
        formatted_minimum_price: (1,1,36),
        debt_buffer: 50000,
        vesting: 0,
        conclusion: start_time + 2 * 24 * 3600,
        deposit_interval: 2 * 3600,
        scale_adjustment: 0,
        scale_adjustment_positive: true
    };
    let seller_b256 = Bits256(*seller_id);
    let floor_b256 = Bits256(*floor_id);
    let vendor_b256 = Bits256(*vendor_id);

    Ok(())
}