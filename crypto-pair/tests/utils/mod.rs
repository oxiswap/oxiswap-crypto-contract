use fuels::{
    prelude::{WalletUnlocked, AssetId},
    types::ContractId
};

use test_utils::{
    structs::WalletAssetConfiguration,
    interface::Pair,
    setup::common::{deploy_pair, setup_wallet_and_provider},
};


pub(crate) async fn setup() -> (WalletUnlocked, Pair<WalletUnlocked>, Vec<(AssetId, AssetId)>, ContractId) {
    let (wallet, asset_ids, _provider) = setup_wallet_and_provider(&WalletAssetConfiguration::default()).await;

    let pair = deploy_pair(&wallet).await;

    let asset_pairs = vec![(asset_ids[0], asset_ids[1]), (asset_ids[2], asset_ids[3])];

    (wallet, pair.instance, asset_pairs, pair.id)
}