use fuels::{prelude::{AssetId, WalletUnlocked}, types::ContractId};
use test_utils::{
    structs::WalletAssetConfiguration,
    interface::Factory,
    setup::common::{deploy_factory, setup_wallet_and_provider},
};


pub async fn setup() -> (WalletUnlocked, Factory<WalletUnlocked>, Vec<(AssetId, AssetId)>, ContractId) {
    let (wallet, asset_ids, _provider) = setup_wallet_and_provider(&WalletAssetConfiguration::default()).await;
    
    let factory = deploy_factory(&wallet).await;

    let asset_pairs = vec![(asset_ids[0], asset_ids[1]), (asset_ids[0], asset_ids[1])];
    
    (wallet, factory.instance, asset_pairs, factory.id)
}