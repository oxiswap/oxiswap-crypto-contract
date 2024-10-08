use fuels::{
    prelude::{WalletUnlocked, AssetId},
    types::ContractId,
};

use test_utils::{
    interface::Router,
    structs::WalletAssetConfiguration,
    setup::common::{deploy_router, setup_wallet_and_provider},
};


pub(crate) async fn setup() -> (WalletUnlocked, Router<WalletUnlocked>, Vec<(AssetId, AssetId)>, ContractId) {
    let (wallet, asset_ids, _provider) = setup_wallet_and_provider(&WalletAssetConfiguration::default()).await;

    let pair = deploy_router(&wallet).await;

    let asset_pairs = vec![(asset_ids[0], asset_ids[1]), (asset_ids[2], asset_ids[3])];

    (wallet, pair.instance, asset_pairs, pair.id)
}