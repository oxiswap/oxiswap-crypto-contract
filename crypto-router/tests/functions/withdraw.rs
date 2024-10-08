mod success {

    use crate::utils::setup;
    use fuels::programs::calls::Execution;
    use test_utils::{
        interface::router::{constructor, deposit, withdraw},
        setup::common::{deploy_factory, deploy_pair},
    };


    #[tokio::test]
    async fn test_withdraw() {
        let (wallet, instance, asset_pairs, _) = setup().await;
        let factory_contract = deploy_factory(&wallet).await;
        let pair_contract = deploy_pair(&wallet).await;

        constructor(&instance, factory_contract.id, pair_contract.id).await;

        let get_factory = instance
            .methods()
            .get_factory()
            .simulate(Execution::StateReadOnly)
            .await
            .unwrap()
            .value;

        assert_eq!(get_factory, factory_contract.id);

        deposit(&instance, asset_pairs[0].0, 1_000_000).await;
        withdraw(&instance, asset_pairs[0].0, 1_000_000).await;

    }
}