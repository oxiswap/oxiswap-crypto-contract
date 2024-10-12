library;

pub mod structs;

use std::u128::U128;


abi Pair {
    #[storage(read)]
    fn get_owner() -> Address;

    #[storage(read)]
    fn get_k(pool: AssetId) -> U128;

    #[storage(read)]
    fn get_reserves(pool: AssetId) -> (u64, u64, u64);

    #[storage(read, write)]
    fn constructor(factory: ContractId);

    #[storage(read, write)]
    fn initialize(pool: AssetId, token0: AssetId, token1: AssetId);

    #[storage(read, write)]
    fn mint(pool: AssetId, to: Identity, amount0: u64, amount1: u64) -> u64;

    #[payable, storage(read, write)]
    fn burn(pool: AssetId, to: Identity) -> (u64, u64);

    #[payable, storage(read, write)]
    fn swap(pool: AssetId, amount0_out: u64, amount1_out: u64, to: Identity);

    #[storage(read)]
    fn skim(pool: AssetId, to: Identity);
}


abi Factory {
    #[storage(read, write)]
    fn constructor(fee_to: Address, pool: ContractId);

    #[storage(read)]
    fn get_pair(asset0: AssetId, asset1: AssetId) -> AssetId;
    
    #[storage(read)]
    fn get_assets(pair: AssetId) -> (AssetId, AssetId);

    #[storage(read)]
    fn check_asset_registry(pair: AssetId, asset0: AssetId, asset1: AssetId) -> bool;

    #[storage(read)]
    fn fee_to() -> Address;

    #[storage(read)]
    fn fee_to_setter() -> Address;

    #[storage(read)]
    fn all_pairs_length() -> u64;

    #[storage(read, write)]
    fn create_pair(token0: AssetId, token1: AssetId) -> AssetId;

    #[storage(read, write)]
    fn set_fee_to(new_fee_to: Address);

    #[storage(read, write)]
    fn set_fee_to_setter(new_fee_to_setter: Address);
}


abi Router {
    #[storage(read, write)]
    fn constructor(factory: ContractId, pool: ContractId);

    #[storage(read, write)]
    fn add_liquidity(
        asset0: AssetId, 
        asset1: AssetId, 
        amount0_desired: u64, 
        amount1_desired: u64, 
        amount0_min: u64, 
        amount1_min: u64,
        to: Identity,
        deadline: u64
    ) -> (u64, u64, u64);

    #[payable, storage(read, write)]
    fn remove_liquidity(
        asset0: AssetId,
        asset1: AssetId,
        liquidity: u64,
        amount0_min: u64,
        amount1_min: u64,
        to: Identity,
        deadline: u64
    ) -> (u64, u64);

    #[payable, storage(read, write)]
    fn deposit() -> bool;

    #[storage(read, write)]
    fn withdraw(asset_id: AssetId, amount: u64) -> bool;

    #[payable, storage(read, write)]
    fn swap_exact_input(
        amount_in: u64,
        amount_out_min: u64,
        path: Vec<AssetId>,
        to: Identity,
        deadline: u64
    ) -> Vec<u64>;

    #[payable, storage(read, write)]
    fn swap_exact_output(
        amount_out: u64,
        amount_in_max: u64,
        path: Vec<AssetId>,
        to: Identity,
        deadline: u64
    ) -> Vec<u64>;

    #[storage(read)]
    fn get_factory() -> ContractId;

    #[storage(read)]
    fn quote(amount0: u64, reserve0: u64, reserve1: u64) -> u64;

    #[storage(read)]
    fn get_amounts_out(amount_in: u64, path: Vec<AssetId>) -> Vec<u64>;

    #[storage(read)]
    fn get_amounts_in(amount_out: u64, path: Vec<AssetId>) -> Vec<u64>;

    #[storage(read)]
    fn get_deposits(sender: Identity, asset: AssetId) -> u64;
}

