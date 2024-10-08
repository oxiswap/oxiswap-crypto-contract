mod success {

    use crate::utils::setup;
    use fuels::{
        types::{bech32::Bech32ContractId, Address, AssetId},
        programs::calls::Execution
    };
    use test_utils::{
        interface::{pair, router::{add_liquidity, constructor, deposit, swap_exact_output}},
        setup::common::{deploy_factory, deploy_pair},
    };
    use std::time::{SystemTime, UNIX_EPOCH};
    use fuels::accounts::ViewOnlyAccount;

    const TWO_POW_62: u64 = 4611686018427387904; // 2^62

    #[tokio::test]
    async fn test_swap_exact_output() {
        let (wallet, instance, asset_pairs, id) = setup().await;
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
        let asset0 = asset_pairs[0].0;
        let asset1 = asset_pairs[0].1;

        for i in 0..2 {
            let amount = 2_000_000_000_000;
            let asset_id = match i {
                0 => asset0,
                1 => asset1,
                _ => AssetId::zeroed(),
            };

            deposit(&instance, asset_id, amount).await;
        }
        
        // let con_ban = wallet
        //     .try_provider()
        //     .unwrap()
        //     .get_contract_balances(&Bech32ContractId::from(id))
        //     .await
        //     .unwrap();

        // println!("router balances {:?}", con_ban);


        let amount0_desired = 2_000_000_000_000;
        let amount1_desired = 2_000_000_000_000;
        let amount0_min = 0;
        let amount1_min = 0;
        let to: Address = wallet.address().into();

        println!("{:?}", (asset0, asset1));
        // println!("{:?}", wallet.get_balances().await.unwrap());

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
        
        println!("====================================");


        let path: Vec<AssetId> = vec![asset0, asset1];
        let amount_out = 100_000_000u64;
        let get_amount_in = instance
            .methods()
            .get_amounts_in(amount_out, path.clone())
            .with_contracts(&[&pair_contract.instance])
            .simulate(Execution::StateReadOnly)
            .await
            .unwrap()
            .value;
        println!("{:?}", get_amount_in);

        let path1: Vec<AssetId> = vec![asset1, asset0];
        let amount_out = 100_000_000u64;
        let get_amount_in = instance
            .methods()
            .get_amounts_in(amount_out, path1.clone())
            .with_contracts(&[&pair_contract.instance])
            .simulate(Execution::StateReadOnly)
            .await
            .unwrap()
            .value;
        println!("{:?}", get_amount_in);

        // let amounts = swap_exact_output(
        //     &instance,
        //     &pair_contract.instance,
        //     amount_out,
        //     get_amount_in[0] * 110 / 100,
        //     path.clone(),
        //     to, 
        //     deadline
        // ).await;

        // println!("{:?}", amounts.value);


        // let t = pair_contract.instance
        //     .methods()
        //     .get_t()
        //     .simulate()
        //     .await
        //     .unwrap()
        //     .value;

        // println!("{:?}", t);

        // let rt = instance
        //     .methods()
        //     .get_t()
        //     .simulate()
        //     .await
        //     .unwrap()
        //     .value;
        // println!("{:?}", rt);

        

    }
}


