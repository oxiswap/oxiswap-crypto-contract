mod success {
    
    use crate::utils::setup;
    use fuels::{
        prelude::*, types::{bech32::Bech32ContractId, Address, AssetId},
        programs::calls::Execution
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
        let (wallet, instance, asset_pairs, id) = setup().await;
        let factory_contract = deploy_factory(&wallet).await;

        constructor(&instance, factory_contract.id).await;
        let wallets = launch_custom_provider_and_get_wallets(WalletsConfig::default(), None, None).await.unwrap();

        let fee_to: Address = wallet.address().into();
        let fac_fee_to: Address = wallets[0].address().into();
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

    }
}