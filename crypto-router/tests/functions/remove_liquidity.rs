mod success {

    use crate::utils::setup;
    use fuels::{
        types::{Address, AssetId, Identity},
        programs::calls::Execution
    };
    use test_utils::{
        interface::router::{constructor, deposit, add_liquidity, remove_liquidity},
        setup::common::{deploy_factory, deploy_pair},
    };
    use std::time::{SystemTime, UNIX_EPOCH};

    const TWO_POW_62: u64 = 4611686018427387904; // 2^62

    #[tokio::test]
    async fn test_remove_liquidity() {
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

        let fee_to: Address = wallet.address().into();
        factory_contract.instance
            .methods()
            .constructor(fee_to, pair_contract.id)
            .call()
            .await
            .unwrap();

        pair_contract.instance
            .methods()
            .constructor(factory_contract.id)
            .call()
            .await
            .unwrap();

        // factory_contract.instance
        //     .methods()
        //     .create_pair(asset_pairs[0].0, asset_pairs[0].1)
        //     .with_contracts(&[&pair_contract.instance])
        //     .call()
        //     .await
        //     .unwrap();

        for i in 0..2 {
            let amount = 2_000_000;
            let asset_id = match i {
                0 => asset_pairs[0].0,
                1 => asset_pairs[0].1,
                _ => AssetId::zeroed(),
            };

            deposit(&instance, asset_id, amount).await;
        }
        

        let asset0 = asset_pairs[0].0;
        let asset1 = asset_pairs[0].1;
        let amount0_desired = 1_000_000;
        let amount1_desired = 1_000_000;
        let amount0_min = 0;
        let amount1_min = 0;
        let to: Identity = Identity::Address(wallet.address().into());

        let now = SystemTime::now();
        let deadline = now.duration_since(UNIX_EPOCH)
            .expect("time")
            .as_secs() + TWO_POW_62 + 1800;

        add_liquidity(
            &instance, 
            &pair_contract.instance, 
            &factory_contract.instance, 
            asset0, 
            asset1, 
            amount0_desired, 
            amount1_desired, 
            amount0_min, 
            amount1_min, 
            to, 
            deadline
        ).await;

        let pool = factory_contract.instance
            .methods()
            .get_pair(asset0, asset1)
            .simulate(Execution::StateReadOnly)
            .await
            .unwrap()
            .value;

        remove_liquidity(
            &instance,
            pool,
            &pair_contract.instance,
            &factory_contract.instance,
            asset0,
            asset1,
            100_000,
            0,
            0,
            to,
            deadline
        ).await;


    }
}


