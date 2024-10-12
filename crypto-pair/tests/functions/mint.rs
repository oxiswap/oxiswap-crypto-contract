mod success {
    
    use crate::utils::setup;
    use fuels::{
        prelude::*, 
        programs::calls::Execution, 
        types::{
            bech32::{
                Bech32ContractId, 
                Bech32Address
            }, 
            Address, 
            AssetId, 
            Identity
        }
    };
    use test_utils::{
        interface::{
            pair::{constructor, mint},
            factory::create_pair,
        },
        setup::common::deploy_factory
    };


    #[tokio::test]
    async fn test_mint() {
        let (wallet, instance, asset_pairs, id, providers) = setup().await;
        let factory_contract = deploy_factory(&wallet).await;

        constructor(&instance, factory_contract.id).await;
        let wallets = launch_custom_provider_and_get_wallets(WalletsConfig::default(), None, None).await.unwrap();

        let fee_to: Identity = Identity::Address(wallet.address().into());
        let fac_fee_to: Address = wallets[1].address().into();
        factory_contract.instance
            .methods()
            .constructor(fac_fee_to, id)
            .call()
            .await
            .unwrap();

        let get_fee_to = factory_contract.instance
            .methods()
            .fee_to()
            .simulate(Execution::StateReadOnly)
            .await
            .unwrap()
            .value;

        assert_eq!(get_fee_to, fac_fee_to);

        let response = create_pair(&factory_contract.instance, asset_pairs[0].0, asset_pairs[0].1, &instance).await;
        assert!(response.value != AssetId::zeroed());
        println!("Pool Asset Id:: {:?}", response.value);

        let pool = response.value;
        for i in 0..2 {
            let amount = 1_000_000_000;

            let asset_id = match i {
                0 => asset_pairs[0].0,
                1 => asset_pairs[0].1,
                _ => AssetId::zeroed()
            };
            
            let (_tx_id, _receipts) = wallet
                .force_transfer_to_contract(&Bech32ContractId::from(id), amount, asset_id, TxPolicies::default())
                .await
                .unwrap();
        }

        mint(&instance, pool, fee_to, 1_000_000_000u64, 1_000_000_000u64, &factory_contract.instance).await;

        let get_reserves = instance
            .methods()
            .get_reserves(pool)
            .simulate(Execution::StateReadOnly)
            .await
            .unwrap()
            .value;
        
        assert_eq!(get_reserves.0, 1_000_000_000);
        assert_eq!(get_reserves.1, 1_000_000_000);

        // let owner_liquidity_for_1 = providers
        //     .get_balances(&Bech32Address::from(wallet.address()))
        //     .await
        //     .unwrap();

        // println!("owner_liquidity_for_1:: {:?}", owner_liquidity_for_1);


        // mint 2
        for i in 0..2 {
            let amount = 1_000_000_000;

            let asset_id = match i {
                0 => asset_pairs[0].0,
                1 => asset_pairs[0].1,
                _ => AssetId::zeroed()
            };
            
            let (_tx_id, _receipts) = wallet
                .force_transfer_to_contract(&Bech32ContractId::from(id), amount, asset_id, TxPolicies::default())
                .await
                .unwrap();
        }


        mint(&instance, pool, fee_to, 1_000_000_000u64, 1_000_000_000u64, &factory_contract.instance).await;

        let k_last = instance
            .methods()
            .get_k(pool)
            .simulate(Execution::StateReadOnly)
            .await
            .unwrap()
            .value;
        
        assert!(k_last > 0);

        // let owner_liquidity_for_2 = providers
        //     .get_balances(&Bech32Address::from(wallet.address()))
        //     .await
        //     .unwrap();

        // println!("owner_liquidity_for_2:: {:?}", owner_liquidity_for_2);

        // let fee_receive_for_1 = providers
        //     .get_balances(&Bech32Address::from(fac_fee_to))
        //     .await
        //     .unwrap();

        // println!("fee_receive_for_1::{:?}", fee_receive_for_1);

        // mint 3 test send fee to owner
        for i in 0..2 {
            let amount = 1_000_000_000;

            let asset_id = match i {
                0 => asset_pairs[0].0,
                1 => asset_pairs[0].1,
                _ => AssetId::zeroed()
            };
            
            let (_tx_id, _receipts) = wallet
                .force_transfer_to_contract(&Bech32ContractId::from(id), amount, asset_id, TxPolicies::default())
                .await
                .unwrap();
        }

        mint(&instance, pool, fee_to, 1_000_000_000u64, 1_000_000_000u64, &factory_contract.instance).await;

        // let fee_receive = providers
        //     .get_balances(&Bech32Address::from(fac_fee_to))
        //     .await
        //     .unwrap();

        // println!("fee_receive_for_2:: {:?}", fee_receive);

        // let owner_liquidity = providers
        //     .get_balances(&Bech32Address::from(wallet.address()))
        //     .await
        //     .unwrap();

        // println!("{:?}", owner_liquidity);

    }
}