use super::interface::{Factory, Pair, Router};
use fuels::prelude::{ContractId, WalletUnlocked};

const NUMBER_OF_ASSETS: u64 = 4;
const COINS_PER_ASSET: u64 = 100;
const AMOUNT_PER_COIN: u64 = 1_000_000_000_000_000;


pub struct FactoryContract {
    pub id: ContractId,
    pub instance: Factory<WalletUnlocked>
}


pub struct RouterContract {
    pub id: ContractId,
    pub instance: Router<WalletUnlocked>
}


pub struct PairContract {
    pub id: ContractId,
    pub instance: Pair<WalletUnlocked>
}


pub struct WalletAssetConfiguration {
    pub number_of_assets: u64,
    pub coins_per_asset: u64,
    pub amount_per_coin: u64
}


impl Default for WalletAssetConfiguration {
    fn default() -> Self {
        Self {
            number_of_assets: NUMBER_OF_ASSETS,
            coins_per_asset: COINS_PER_ASSET,
            amount_per_coin: AMOUNT_PER_COIN,
        }
    }
}