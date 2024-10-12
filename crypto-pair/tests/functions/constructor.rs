mod success {
    
    use crate::utils::setup;
    use test_utils::{
        interface::pair::constructor,
        setup::common::deploy_factory,
    };
    use fuels::programs::calls::Execution;


    #[tokio::test]
    async fn test_constructor() {
        let (wallet, instance, _, _, _) = setup().await;
        let factory_contract = deploy_factory(&wallet).await;

        constructor(&instance, factory_contract.id).await;

        let owner = instance
            .methods()
            .get_owner()
            .simulate(Execution::StateReadOnly)
            .await
            .unwrap()
            .value;

        assert_eq!(owner, wallet.address().into());
        println!("{:?}", owner);
    }
}