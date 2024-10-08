use super::structs::{FactoryContract, PairContract, RouterContract};
use fuels::prelude::*;


pub mod common {
    use super::*;

    use crate::{
        structs::WalletAssetConfiguration,
        interface::{Factory, Pair, Router},
        paths::{
            CRYPTO_FACTORY_BIN_PATH, CRYPTO_PAIR_BIN_PATH,
            CRYPTO_ROUTER_BIN_PATH, CRYPTO_FACTORY_STORAGE_PATH,
            CRYPTO_PAIR_STORAGE_PATH, CRYPTO_ROUTER_STORAGE_PATH
        },
    };

    pub async fn deploy_factory(wallet: &WalletUnlocked) -> FactoryContract {
        let storage_configuration = StorageConfiguration::default()
            .add_slot_overrides_from_file(CRYPTO_FACTORY_STORAGE_PATH)
            .unwrap();

        let configuration = LoadConfiguration::default().with_storage_configuration(storage_configuration);

        let contract_id = Contract::load_from(CRYPTO_FACTORY_BIN_PATH, configuration)
            .unwrap()
            .deploy(wallet, TxPolicies::default())
            .await
            .unwrap();

        let instance = Factory::new(contract_id.clone(), wallet.clone());
        
        FactoryContract {
            id: contract_id.into(),
            instance
        }
    }


    pub async fn deploy_router(wallet: &WalletUnlocked) -> RouterContract {
        let storage_configuration = StorageConfiguration::default()
            .add_slot_overrides_from_file(CRYPTO_ROUTER_STORAGE_PATH)
            .unwrap();

        let configuration = LoadConfiguration::default()
            .with_storage_configuration(storage_configuration);

        let contract_id = Contract::load_from(CRYPTO_ROUTER_BIN_PATH, configuration)
            .unwrap()
            .deploy(wallet, TxPolicies::default())
            .await
            .unwrap();

        let instance = Router::new(contract_id.clone(), wallet.clone());

        RouterContract {
            id: contract_id.into(),
            instance
        }
    }


    pub async fn deploy_pair(wallet: &WalletUnlocked) -> PairContract {
        let storage_configuration = StorageConfiguration::default()
            .add_slot_overrides_from_file(CRYPTO_PAIR_STORAGE_PATH)
            .unwrap();

        let configuration = LoadConfiguration::default()
            .with_storage_configuration(storage_configuration);

        let contract_id = Contract::load_from(CRYPTO_PAIR_BIN_PATH, configuration)
            .unwrap()
            .deploy(wallet, TxPolicies::default())
            .await
            .unwrap();

        let instance = Pair::new(contract_id.clone(), wallet.clone());

        PairContract {
            id: contract_id.into(),
            instance
        }
    }


    pub async fn setup_wallet_and_provider(asset_paramenters: &WalletAssetConfiguration) -> (WalletUnlocked, Vec<AssetId>, Provider) {
        let mut wallet = WalletUnlocked::new_random(None);

        let (coins, asset_ids) = setup_multiple_assets_coins(
            wallet.address(),
            asset_paramenters.number_of_assets,
            asset_paramenters.coins_per_asset,
            asset_paramenters.amount_per_coin,
        );

        let provider = setup_test_provider(coins.clone(), vec![], None, None)
            .await
            .unwrap();
        
        wallet.set_provider(provider.clone());

        (wallet, asset_ids, provider)
    }


}