use crate::utils::setup;
use test_utils::{
    interface::factory::{constructor, create_pair},
    setup::common::deploy_pair,
};


mod success {
    use super::*;

    #[tokio::test]
    async fn test_create_pair() {
        let (wallet, instance, asset_pairs, id) = setup().await;
        let pair_contract = deploy_pair(&wallet).await;

        pair_contract.instance
            .methods()
            .constructor(id)
            .call()
            .await
            .unwrap();

        constructor(&instance, wallet.address().into(), pair_contract.id).await;

        let response = create_pair(&instance, asset_pairs[0].0, asset_pairs[0].1, &pair_contract.instance).await;
        
        print!("{:?}", response.value);
    }
}