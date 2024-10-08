use crate::utils::setup;
use test_utils::{
    interface::factory::constructor,
    setup::common::deploy_pair,
};
use fuels::programs::calls::Execution;

mod success {
    use super::*;

    #[tokio::test]
    async fn test_constructor() {
        let (wallet, instance, _asset_pairs, _id) = setup().await;
        let pair_contract = deploy_pair(&wallet).await;

        constructor(&instance, wallet.address().into(), pair_contract.id).await;

        let response = instance
            .methods()
            .fee_to()
            .simulate(Execution::StateReadOnly)
            .await
            .unwrap()
            .value;
        
        assert_eq!(response, wallet.address().into());
    }
}