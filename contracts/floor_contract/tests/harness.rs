use fuels::{prelude,prelude::*, tx::ContractId, types::Identity,tx::Bytes32,types::Bits256};
use std::str::FromStr;
use rand::{Fill,*};


use std::{thread, time};
use chrono::{Utc, TimeZone, Duration};
use tai64::Tai64;

// Load abi from json
abigen!(
    Contract( name="Floor", abi="out/debug/floor_contract-abi.json"),
    Contract( name="Vendor", abi="../vendor_contract/out/debug/vendor_contract-abi.json"),
    Contract( name="Seller", abi="../seller_contract/out/debug/seller_contract-abi.json"),
);

async fn get_contract_instance() -> (Floor, ContractId,Vendor, ContractId, Seller, ContractId, WalletUnlocked, WalletUnlocked, AssetId,AssetId) {

    let mut rng = rand::thread_rng();

    let asset_base = AssetConfig {
        id: BASE_ASSET_ID,
        num_coins: 2,
        coin_amount: 1_000_000_000_000,
    };

    let mut asset_id_1 = AssetId::zeroed();
    asset_id_1.try_fill(&mut rng);
    let asset_1 = AssetConfig {
        id: asset_id_1,
        num_coins: 6,
        coin_amount: 1_000_000_000_000,
    };

    let mut asset_id_2 = AssetId::zeroed();
    asset_id_2.try_fill(&mut rng);
    let asset_2 = AssetConfig {
        id: asset_id_2,
        num_coins: 10,
        coin_amount: 1_000_000_000_000,
    };

    let assets = vec![asset_base, asset_1, asset_2];
    let num_wallets = 2;
    let wallet_config = WalletsConfig::new_multiple_assets(num_wallets, assets);

    // Launch a local network and deploy the contract
    let mut wallets = launch_custom_provider_and_get_wallets(
        wallet_config,
        None,
        None,
    )
    .await;
    let wallet1 = wallets.pop().unwrap();
    let wallet2 = wallets.pop().unwrap();

    let id = Contract::deploy(
        "./out/debug/floor_contract.bin",
        &wallet1,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./out/debug/floor_contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let instance = Floor::new(id.clone(), wallet1.clone());

    let vendor_id = Contract::deploy(
        "../vendor_contract/out/debug/vendor_contract.bin",
        &wallet1,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "../vendor_contract/out/debug/vendor_contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let vendor_instance = Vendor::new(vendor_id.clone(), wallet1.clone());

    // deploy seller contract
    let seller_id = Contract::deploy(
        "../seller_contract/out/debug/seller_contract.bin",
        &wallet1,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "../seller_contract/out/debug/seller_contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let seller_instance = Seller::new(seller_id.clone(), wallet1.clone());


    let id_bech32: ContractId = id.clone().into();

    //initialize vendor
    let result = vendor_instance.methods()
        .initialize( Bits256(*BASE_ASSET_ID),Bits256(*id_bech32))
        .set_contracts(&[&vendor_instance, &instance])
        .call().await.unwrap();

    (instance, id.into(), vendor_instance,vendor_id.into(),seller_instance,seller_id.into(), wallet1.clone(), wallet2.clone(), asset_id_1,asset_id_2)
}

#[tokio::test]
async fn can_get_contract_id() -> Result<()> {
    let (_instance, _id,vendor_instance,vendor_id, seller_instance, seller_id,wallet1, wallet2, asset_id_1, asset_id_2) = get_contract_instance().await;

    // Now you have an instance of your contract you can use to test each function
    Ok(())
}

#[tokio::test]
async fn can_initialize() -> Result<()> {
    let (_instance, _id,vendor_instance,vendor_id, seller_instance, seller_id,wallet1, wallet2, asset_id_1, asset_id_2) = get_contract_instance().await;

    let result = _instance.methods()
        .initialize(Bits256(*_id), Identity::Address(Address::from(wallet1.address())))
        .set_contracts(&[&_instance])
        .call().await?;
    // Now you have an instance of your contract you can use to test each function
    Ok(())
}



#[tokio::test]
async fn can_transfer_owner() -> Result<()> {
    let (_instance, _id,vendor_instance,vendor_id, seller_instance, seller_id,wallet1, wallet2, asset_id_1, asset_id_2) = get_contract_instance().await;
    let result = _instance.methods()
        .initialize(Bits256(*_id), Identity::Address(Address::from(wallet1.address())))
        .set_contracts(&[&_instance])
        .call().await?;
    // Now you have an instance of your contract you can use to test each function
    let result1 = _instance.methods()
        .transfer_owner(Identity::Address(Address::from(wallet2.address())))
        .set_contracts(&[&_instance])
        .call().await?;
    Ok(())
}


#[tokio::test]
async fn can_register_vendor() -> Result<()> {
    let (_instance, _id,vendor_instance,vendor_id, seller_instance, seller_id,wallet1, wallet2, asset_id_1, asset_id_2) = get_contract_instance().await;
    let result = _instance.methods()
        .initialize(Bits256(*_id), Identity::Address(Address::from(wallet1.address())))
        .set_contracts(&[&_instance])
        .call().await?;
    // Now you have an instance of your contract you can use to test each function
    let result1 = _instance.methods()
        .register_vendor(Bits256(*(wallet2.address().hash())))
        .set_contracts(&[&_instance])
        .call().await?;
    Ok(())
}

#[tokio::test]
async fn can_register_market() -> Result<()> {
    let (_instance, _id,vendor_instance,vendor_id, seller_instance, seller_id,wallet1, wallet2, asset_id_1, asset_id_2) = get_contract_instance().await;
    let result = _instance.methods()
        .initialize(Bits256(*_id), Identity::Address(Address::from(wallet1.address())))
        .set_contracts(&[&_instance])
        .call().await?;

    
    // Now you have an instance of your contract you can use to test each function

    // Test auth when not owner
    let result1 = _instance.methods()
        .register_vendor(Bits256(*(wallet2.address().hash())))
        .set_contracts(&[&_instance])
        .call().await?;

    let result2 = _instance.methods()
        .register_market(Bits256(*(asset_id_1)), Bits256(*(asset_id_1)))
        .set_contracts(&[&_instance])
        .call().await;
    assert!(matches!(result2, Err(prelude::Error::RevertTransactionError { .. })));

    Ok(())
}

#[tokio::test]
async fn can_get_vendor() -> Result<()> {
    let (_instance, _id,vendor_instance,vendor_id, seller_instance, seller_id,wallet1, wallet2, asset_id_1, asset_id_2) = get_contract_instance().await;
    let result = _instance.methods()
    .initialize(Bits256(*_id), Identity::Address(Address::from(wallet1.address())))
    .set_contracts(&[&_instance])
    .call().await?;

    let my_tx_params = TxParameters::new(None, Some(10_000_000), None);
    let start_time = u64::from_be_bytes(Tai64::now().to_bytes());
    let vesting:u64 = u64::from_be_bytes((Tai64::now() +24 * 3600).to_bytes());
    let conclusion:u64 = u64::from_be_bytes((Tai64::now() +2*24 * 3600).to_bytes());;
    let deposit_interval: u64 = 3600;

    let market_params = MarketParams {
        payout_token: Bits256(*asset_id_1),
        quote_token: Bits256(*asset_id_2),
        callback_addr: Bits256([0u8;32]), // random id
        capacity_in_quote: true,
        capacity: 1000,
        formatted_initial_price: (1,1,18),
        formatted_minimum_price: (1,1,18),
        debt_buffer: 10,
        vesting: vesting,
        conclusion: conclusion,
        deposit_interval: deposit_interval,
        scale_adjustment: 18,
        scale_adjustment_positive: true
    };
    // Add vender now
    let result3 = _instance.methods()
    .register_vendor(Bits256(*(vendor_id)))
    .set_contracts(&[&_instance, &vendor_instance])
    .call().await?;

    let result4 = vendor_instance.methods()
        .create_market(market_params)
        .set_contracts(&[&_instance, &vendor_instance])
        .tx_params(my_tx_params)
        .call().await?;
    // // Now you have an instance of your contract you can use to test each function
    let result5 = _instance.methods()
        .get_vendor(result4.value)
        .set_contracts(&[&_instance])
        .call().await?;

    // // compare vendor address
    assert_eq!(result5.value, Bits256(*(vendor_id)));

    Ok(())
}


// TODO: Add Seller Instance to allow puchase of bond, and activate bond price adjustments. This is necessary to get price
#[tokio::test]
async fn can_get_market_price() -> Result<()> {
    let (_instance, _id,vendor_instance,vendor_id, seller_instance, seller_id,wallet1, wallet2, asset_id_1, asset_id_2) = get_contract_instance().await;
    let result = _instance.methods()
        .initialize(Bits256(*_id), Identity::Address(Address::from(wallet1.address())))
        .set_contracts(&[&_instance])
        .call().await?;
        let my_tx_params = TxParameters::new(None, Some(10_000_000), None);
        let start_time = u64::from_be_bytes(Tai64::now().to_bytes());
        let vesting:u64 = u64::from_be_bytes((Tai64::now() +24 * 3600).to_bytes());
        let conclusion:u64 = u64::from_be_bytes((Tai64::now() +2*24 * 3600).to_bytes());;
        let deposit_interval: u64 = 3600;

        let market_params = MarketParams {
            payout_token: Bits256(*asset_id_1),
            quote_token: Bits256(*asset_id_2),
            callback_addr: Bits256([0u8;32]), // random id
            capacity_in_quote: true,
            capacity: 3600,
            formatted_initial_price: (1,1,18),
            formatted_minimum_price: (1,1,18),
            debt_buffer: 10,
            vesting: vesting,
            conclusion: conclusion,
            deposit_interval: deposit_interval,
            scale_adjustment: 18,
            scale_adjustment_positive: true
        };
        // Add vender now
        let result3 = _instance.methods()
        .register_vendor(Bits256(*(vendor_id)))
        .set_contracts(&[&_instance, &vendor_instance])
        .call().await?;

        let result4 = vendor_instance.methods()
            .create_market(market_params)
            .set_contracts(&[&_instance, &vendor_instance])
            .tx_params(my_tx_params)
            .call().await?;

    // purchase bond through seller and get market price

    // Now you have an instance of your contract you can use to test each function
    // let result6 = _instance.methods()
    //     .market_price(result4.value)
    //     .set_contracts(&[&_instance, &vendor_instance])
    //     .call().await?;

    // assert_eq!(result6.value, 10);
    
    Ok(())
}

