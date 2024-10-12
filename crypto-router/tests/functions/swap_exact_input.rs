mod success {

    use crate::utils::setup;
    use fuels::{
        types::{bech32::Bech32ContractId, Address, AssetId, Identity},
        programs::calls::Execution
    };
    use test_utils::{
        interface::router::{add_liquidity, constructor, deposit, swap_exact_input},
        setup::common::{deploy_factory, deploy_pair},
    };
    use std::time::{SystemTime, UNIX_EPOCH};
    use fuels::accounts::ViewOnlyAccount;

    const TWO_POW_62: u64 = 4611686018427387904; // 2^62

    #[tokio::test]
    async fn test_swap_exact_input() {
        let (wallet, instance, asset_pairs, _id) = setup().await;
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
        println!("wallet address ==== {:?}", fee_to);

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
            let amount = 2_000_000_000;
            let asset_id = match i {
                0 => asset_pairs[0].0,
                1 => asset_pairs[0].1,
                _ => AssetId::zeroed(),
            };

            deposit(&instance, asset_id, amount).await;
        }
        

        let asset0 = asset_pairs[0].0;
        let asset1 = asset_pairs[0].1;
        let amount0_desired = 1_000_000_000;
        let amount1_desired = 1_000_000_000;
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

        let path: Vec<AssetId> = vec![asset1, asset0];

        let amounts = swap_exact_input(
            &instance,
            &pair_contract.instance,
            100_311,
            0,
            path,
            to, 
            deadline
        ).await;
        println!("{:?}", amounts.value);

        let con_ban = wallet
            .try_provider()
            .unwrap()
            .get_contract_balances(&Bech32ContractId::from(pair_contract.id))
            .await
            .unwrap();

        println!("{:?}", con_ban);

    }
}


