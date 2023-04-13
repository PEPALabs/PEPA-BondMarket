use fuels::{prelude::*, tx::ContractId, types::*, types::transaction::TxParameters};
use std::io;
use std::collections::HashMap;
use std::{thread, time};
use rand::Fill;
use chrono::{Utc, TimeZone, Duration};
use tai64::Tai64;


fn addr_to_b256(addr: &Bech32Address) -> Bits256 {
    let a = *addr.hash();
    Bits256(a)
}

#[tokio::test]
async fn test_bid() -> Result<()>{
    abigen!(Contract(name = "Owner", abi = "out/debug/owner_wallet_contract-abi.json"));
    let mut rng = rand::thread_rng();

    let asset_base = AssetConfig {
        id: BASE_ASSET_ID,
        num_coins: 1,
        coin_amount: 1000000000000,
    };

    let mut quote_id = AssetId::zeroed();
    quote_id.try_fill(&mut rng);
    let asset_quote = AssetConfig {
        id: quote_id,
        num_coins: 1,
        coin_amount: 1000000,
    };


    let assets = vec![asset_base.clone(), asset_quote.clone()];

    let num_wallets = 10;
    let wallet_config = WalletsConfig::new_multiple_assets(num_wallets, assets);
    let wallets = launch_custom_provider_and_get_wallets(wallet_config, None, None).await;

    let bidder1 = wallets.get(0).unwrap();
    let bidder2 = wallets.get(1).unwrap();
    let deployer = wallets.get(2).unwrap();
    let maintainer = wallets.get(3).unwrap();

    let zero_b256 = "0x0000000000000000000000000000000000000000000000000000000000000000";

    let id = Contract::deploy(
        "out/debug/owner_wallet_contract.bin",
        &deployer,
        DeployConfiguration::default(),
    )
    .await
    .unwrap();

    let instance = Owner::new(id.clone(), deployer.clone());
    let sender = instance
                .with_wallet(maintainer.clone()).expect("REASON")
                .methods()
                .sender()
                .call()
                .await
                .unwrap();

    println!("wallet {}", deployer.address().hash());
    println!("maintainer {}", maintainer.address().hash());
    println!("address {}", sender.value);

    Ok(())
}
