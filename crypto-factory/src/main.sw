contract;

mod errors;
mod events;

use errors::*;
use events::*;
use std::{
    auth::msg_sender,
    contract_id::ContractId,
    hash::*
};

use libraries::{
    Pair, 
    Factory
};


storage {
    fee_to: Address = Address::zero(),
    owner: Address = Address::zero(),
    pool: ContractId = ContractId::zero(),
    all_pairs: StorageMap<u64, AssetId> = StorageMap {},
    get_pair: StorageMap<(AssetId, AssetId), AssetId> = StorageMap {},
    get_assets: StorageMap<AssetId, (AssetId, AssetId)> = StorageMap {},
    all_pairs_length: u64 = 0,
    is_initialized: bool = false
}


impl Factory for Contract {
    #[storage(read, write)]
    fn constructor(fee_to: Address, pool: ContractId) {
        require(!storage.is_initialized.read(), FactoryErr::Initialized);
        
        storage.owner.write(msg_sender().unwrap().as_address().unwrap());
        storage.fee_to.write(fee_to);
        storage.pool.write(pool);
        storage.is_initialized.write(true);
    }


    #[storage(read)]
    fn get_pair(asset0: AssetId, asset1: AssetId) -> AssetId {
        storage.get_pair.get((asset0, asset1)).try_read().unwrap_or(AssetId::zero())
    }


    #[storage(read)]
    fn get_assets(pair: AssetId) -> (AssetId, AssetId) {
        storage.get_assets.get(pair).try_read().unwrap_or((AssetId::zero(), AssetId::zero()))
    }


    #[storage(read)]
    fn fee_to() -> Address {
        storage.fee_to.read()
    }


    #[storage(read)]
    fn fee_to_setter() -> Address {
        storage.owner.read()
    }


    #[storage(read)]
    fn all_pairs_length() -> u64 {
        storage.all_pairs_length.read()
    }


    #[storage(read, write)]
    fn create_pair(asset0: AssetId, asset1: AssetId) -> AssetId {
        let asset0_b256: b256 = asset0.into();
        let asset1_b256: b256 = asset1.into();
        require(asset0_b256 != asset1_b256, FactoryErr::IdenticalAddresses);

        let (asset_pair, sorted_asset0, sorted_asset1) = if asset0_b256 < asset1_b256 {
            ((asset0, asset1), asset0, asset1)
        } else {
            ((asset1, asset0), asset1, asset0)
        };
        require(!asset0.is_zero(), FactoryErr::ZeroAddress);
        require(storage.get_pair.get((asset_pair)).try_read().unwrap_or(AssetId::zero()).is_zero(), FactoryErr::PairExists);

        let pool_contract_id = storage.pool.read();
        let salt = keccak256((sorted_asset0, sorted_asset1));
        let new_asset_id = sha256((pool_contract_id, salt));
        let new_pair_asset = AssetId::from(new_asset_id);
        let old_length = storage.all_pairs_length.read();

        storage.get_pair.insert((asset0, asset1), new_pair_asset);
        storage.get_pair.insert((asset1, asset0), new_pair_asset);
        storage.get_assets.insert(new_pair_asset, asset_pair);
        storage.all_pairs.insert(old_length, new_pair_asset);
        storage.all_pairs_length.write(old_length + 1);

        let pool_id_b256: b256 = pool_contract_id.into();
        let pair_contract = abi(Pair, pool_id_b256);
        pair_contract.initialize(new_pair_asset, sorted_asset0, sorted_asset1);
        
        log(PairCreated {
            token0: sorted_asset0,
            token1: sorted_asset1,
            pair: new_pair_asset,
            length: old_length
        });

        new_pair_asset
        
    }


    #[storage(read, write)]
    fn set_fee_to(new_fee_to: Address) {
        require(msg_sender().unwrap().as_address().unwrap() == storage.owner.read(), FactoryErr::Forbidden);
        storage.fee_to.write(new_fee_to);
    }


    #[storage(read, write)]
    fn set_fee_to_setter(new_fee_to_setter: Address) {
        require(msg_sender().unwrap().as_address().unwrap() == storage.owner.read(), FactoryErr::Forbidden);
        storage.owner.write(new_fee_to_setter);
    }
}