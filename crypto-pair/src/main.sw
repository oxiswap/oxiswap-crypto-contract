contract;

mod events;
mod errors;
mod utils;

use ::errors::*;
use ::events::*;
use ::utils::*;

use std::{
    asset::{
        mint,
        burn,
        transfer,
    },
    contract_id::ContractId,
    auth::msg_sender,
    call_frames::msg_asset_id,
    context::{
        msg_amount,
        this_balance
    },
    hash::*,
    u128::U128,
    block::timestamp,
    primitive_conversions::{
        u64::*,
        u256::*
    },
    storage::storage_string::*,
    string::String,
};
use sway_libs::reentrancy::*;
use standards::src20::SRC20;
use libraries::{Pair, Factory};


configurable {
    MINIMUM_LIQUIDITY: u64 = 100,
    NAME: str[10] = __to_str_array("Oxiswap V1"),
    SYMBOL: str[6] = __to_str_array("OXI-V1"),
    DECIMALS: u8 = 9u8,
}

storage {
    owner: Address = Address::zero(),
    factory: ContractId = ContractId::zero(),
    block_timestamp_last: StorageMap<AssetId, u64> = StorageMap {},
    price0_cumulative_last: StorageMap<AssetId, U128> = StorageMap {},
    price1_cumulative_last: StorageMap<AssetId, U128> = StorageMap {},
    k_last: StorageMap<AssetId, U128> = StorageMap {},
    total_supply: StorageMap<AssetId, u64> = StorageMap {},
    is_initialized: bool = false,
    pairs: StorageMap<AssetId, AssetPair> = StorageMap {},
    total_balances: StorageMap<AssetId, u64> = StorageMap {},
    total_assets: u64 = 0,
}


impl SRC20 for Contract {
    #[storage(read)]
    fn total_assets() -> u64 {
        storage.total_assets.read()
    }
 
    #[storage(read)]
    fn total_supply(asset: AssetId) -> Option<u64> {
        storage.total_supply.get(asset).try_read()
    }
 
    #[storage(read)]
    fn name(asset: AssetId) -> Option<String> {
        if asset == AssetId::default() {
            Some(String::from_ascii_str(from_str_array(NAME)))
        } else {
            None
        }
    }
 
    #[storage(read)]
    fn symbol(asset: AssetId) -> Option<String> {
        if asset == AssetId::default() {
            Some(String::from_ascii_str(from_str_array(SYMBOL)))
        } else {
            None
        }
    }
 
    #[storage(read)]
    fn decimals(asset: AssetId) -> Option<u8> {
        if asset == AssetId::default() {
            Some(DECIMALS)
        } else {
            None
        }
    }
}


impl Pair for Contract {
    #[storage(read, write)]
    fn constructor(factory: ContractId) {
        require(!storage.is_initialized.read(), BaseError::Initialized);
        
        storage.owner.write(msg_sender().unwrap().as_address().unwrap());
        storage.factory.write(factory);
        storage.is_initialized.write(true);
    }


    #[storage(read, write)]
    fn initialize(pool: AssetId, asset0: AssetId, asset1: AssetId) {
        require(msg_sender().unwrap().bits() == storage.factory.read().bits(), BaseError::Forbidden);

        storage.total_assets.write(storage.total_assets.read() + 1);
        storage.pairs.insert(
            pool,
            AssetPair::new(
                Asset::new(asset0, 0),
                Asset::new(asset1, 0),
            ),
        );
    }


    #[storage(read)]
    fn get_k(pool: AssetId) -> U128 {
        storage.k_last.get(pool).try_read().unwrap_or(U128::zero())
    }


    #[storage(read)]
    fn get_owner() -> Address {
        storage.owner.read()
    }


    #[storage(read)]
    fn get_reserves(pool: AssetId) -> (u64, u64, u64) {
        let pair = storage.pairs.get(pool).try_read().unwrap_or(AssetPair::default());
        (
            pair.asset0.amount,
            pair.asset1.amount,
            storage.block_timestamp_last.get(pool).try_read().unwrap_or(0)
        )
    }


    #[storage(read, write)]
    fn mint(pool: AssetId, to: Identity, amount0: u64, amount1: u64) -> u64 {
        let pair = storage.pairs.get(pool).try_read().unwrap();
        let (asset0, reserve0) = (pair.asset0.id, pair.asset0.amount);
        let (asset1, reserve1) = (pair.asset1.id, pair.asset1.amount);
        
        let fee_on = mint_fee(pool, asset0, asset1, reserve0, reserve1);
        let total_supply = storage.total_supply.get(pool).try_read().unwrap_or(0);
        let mut liquidity = U128::zero();
        let salt = keccak256((asset0, asset1));
        if total_supply == 0 {
            liquidity = sqrt(U128::from((0, amount0)) * U128::from((0, amount1))) - U128::from((0, MINIMUM_LIQUIDITY));
            storage.total_supply.insert(pool, total_supply + MINIMUM_LIQUIDITY);
            mint(salt, MINIMUM_LIQUIDITY);
            transfer(Identity::Address(Address::zero()), pool, MINIMUM_LIQUIDITY);  
        } else {
            liquidity = min(
                U128::from((0, amount0)) * U128::from((0, total_supply)) / U128::from((0, reserve0)), 
                U128::from((0, amount1)) * U128::from((0, total_supply)) / U128::from((0, reserve1))
            );
            
        }

        let liqui = liquidity.as_u64().unwrap();
        require(liqui > 0, BaseError::InsufficientLiquidityMinted);

        storage.total_supply.insert(pool, total_supply + liqui);
        storage.total_balances.insert(
            asset0,
            storage.total_balances
                .get(asset0)
                .try_read()
                .unwrap_or(0) + amount0
        );
        storage.total_balances.insert(
            asset1,
            storage.total_balances
                .get(asset1)
                .try_read()
                .unwrap_or(0) + amount1
        );

        mint(salt, liqui);
        transfer(to, pool, liqui);
        update(pool, reserve0 + amount0, reserve1 + amount1, reserve0, reserve1);

        if fee_on {
            storage.k_last.insert(pool, U128::from((0, reserve0)) * U128::from((0, reserve1)));
        }

        log(MintEvent {
            sender: msg_sender().unwrap(),
            amount0: amount0,
            amount1: amount1
        });

        liqui   
    }


    #[payable, storage(read, write)]
    fn burn(pool: AssetId, to: Identity) -> (u64, u64) {
        let liquidity = this_balance(pool);

        let pair = storage.pairs.get(pool).try_read().unwrap();
        let (asset0, reserve0) = (pair.asset0.id, pair.asset0.amount);
        let (asset1, reserve1) = (pair.asset1.id, pair.asset1.amount);
        
        let fee_on = mint_fee(pool, asset0, asset1, reserve0, reserve1);
        let total_supply = storage.total_supply.get(pool).try_read().unwrap_or(0);
        let amount0 = (U128::from((0, liquidity)) * U128::from((0, reserve0)) / U128::from((0, total_supply))).as_u64().unwrap();
        let amount1 = (U128::from((0, liquidity)) * U128::from((0, reserve1)) / U128::from((0, total_supply))).as_u64().unwrap();
        require(amount0 > 0 && amount1 > 0, BaseError::InsufficientLiquidityBurned);

        storage.total_supply.insert(pool, total_supply - liquidity);
        let salt = keccak256((asset0, asset1));
        burn(salt, liquidity);
        transfer(to, asset0, amount0);
        transfer(to, asset1, amount1);

        storage.total_balances.insert(
            asset0,
            storage.total_balances
                .get(asset0)
                .try_read()
                .unwrap_or(0) - amount0
        );
        storage.total_balances.insert(
            asset1,
            storage.total_balances
                .get(asset1)
                .try_read()
                .unwrap_or(0) - amount1
        );

        update(pool, reserve0 - amount0, reserve1 - amount1, reserve0, reserve1);

        if fee_on {
            storage.k_last.insert(pool, U128::from((0, reserve0 - amount0)) * U128::from((0, reserve1 - amount1)));
        }

        log(BurnEvent {
            sender: msg_sender().unwrap(),
            amount0: amount0,
            amount1: amount1,
            to: to
        });

        (amount0, amount1)
    }


    #[payable, storage(read, write)]
    fn swap(pool: AssetId, amount0_out: u64, amount1_out: u64, to: Identity) {
        require(amount0_out > 0 || amount1_out > 0, BaseError::InsufficientOutputAmount);

        let pair = storage.pairs.get(pool).try_read().unwrap();
        let (asset0, reserve0) = (pair.asset0.id, pair.asset0.amount);
        let (asset1, reserve1) = (pair.asset1.id, pair.asset1.amount);
        require(amount0_out < reserve0 && amount1_out < reserve1, BaseError::InsufficientLiquidity);
        check_asset_registry(pool, asset0, asset1);

        let mut balance0 = 0;
        let mut balance1 = 0;

        {   
            let to_b256: b256 = match to {
                Identity::Address(address) => address.into(),
                Identity::ContractId(contract_id) => contract_id.into(),
            };
            let asset0_b256: b256 = asset0.into();
            let asset1_b256: b256 = asset1.into();
            require(to_b256 != asset0_b256 && to_b256 != asset1_b256, BaseError::InvalidTo);

            let asset0_tb = storage.total_balances.get(asset0).try_read().unwrap_or(0);
            let asset1_tb = storage.total_balances.get(asset1).try_read().unwrap_or(0);
            let deposit0 = this_balance(asset0) - asset0_tb;
            let deposit1 = this_balance(asset1) - asset1_tb;

            let mut new_reserve0 = reserve0;
            let mut new_reserve1 = reserve1;
            if amount0_out > 0 {
                new_reserve0 = reserve0 - amount0_out;
                new_reserve1 = reserve1 + deposit1;
                storage.total_balances.insert(asset0, asset0_tb - amount0_out);
                storage.total_balances.insert(asset1, asset1_tb + deposit1);
                transfer(to, asset0, amount0_out);
            }
            if amount1_out > 0 {
                new_reserve0 = reserve0 + deposit0;
                new_reserve1 = reserve1 - amount1_out;
                storage.total_balances.insert(asset0, asset0_tb + deposit0);
                storage.total_balances.insert(asset1, asset1_tb - amount1_out);
                transfer(to, asset1, amount1_out);
            }
            balance0 = new_reserve0;
            balance1 = new_reserve1;
        }

        
        let amount0_in = if balance0 > reserve0 - amount0_out { balance0 - (reserve0 - amount0_out) } else { 0 };
        let amount1_in = if balance1 > reserve1 - amount1_out { balance1 - (reserve1 - amount1_out) } else { 0 };
        require(amount0_in > 0 || amount1_in > 0, BaseError::InsufficientPairInputAmount);        

        {
            let balance0_adjusted = U128::from((0, balance0)) * U128::from((0, 1000)) - U128::from((0, amount0_in)) * U128::from((0, 3));
            let balance1_adjusted = U128::from((0, balance1)) * U128::from((0, 1000)) - U128::from((0, amount1_in)) * U128::from((0, 3));
            require(balance0_adjusted * balance1_adjusted >= U128::from((0, reserve0)) * U128::from((0, reserve1)) * U128::from((0, 1000**2)), BaseError::K);
        }

        update(pool, balance0, balance1, reserve0, reserve1);
        log(SwapEvent {
            sender: msg_sender().unwrap(),
            amount0_in: amount0_in,
            amount1_in: amount1_in,
            amount0_out: amount0_out,
            amount1_out: amount1_out,
            to: to
        });
    }


    #[storage(read)]
    fn skim(pool: AssetId, to: Identity) {
        let pair = storage.pairs.get(pool).try_read().unwrap();
        let asset0 = pair.asset0.id;
        let asset1 = pair.asset1.id;
        check_asset_registry(pool, asset0, asset1);

        transfer(to, asset0, this_balance(asset0) - storage.total_balances.get(asset0).try_read().unwrap());
        transfer(to, asset1, this_balance(asset1) - storage.total_balances.get(asset1).try_read().unwrap());
    }
}


#[storage(read, write)]
fn update(pool: AssetId, balance0: u64, balance1: u64, reserve0: u64, reserve1: u64) {
    require(balance0 <= u64::max() && balance1 <= u64::max(), BaseError::Overflow);

    let block_timestamp = timestamp() % (2.pow(32));
    let time_elapsed = block_timestamp - storage.block_timestamp_last.get(pool).try_read().unwrap_or(0);

    if (time_elapsed > 0 && reserve0 != 0 && reserve1 != 0) {
        let old_price0 = storage.price0_cumulative_last.get(pool).try_read().unwrap_or(U128::zero());
        let old_price1 = storage.price1_cumulative_last.get(pool).try_read().unwrap_or(U128::zero());
        let new_price0 = old_price0 + uqdiv_q128(encode_q128(reserve1), reserve0) * U128::from((0, time_elapsed));
        let new_price1 = old_price1 + uqdiv_q128(encode_q128(reserve0), reserve1) * U128::from((0, time_elapsed));

        storage.price0_cumulative_last.insert(pool, new_price0);
        storage.price1_cumulative_last.insert(pool, new_price1);
    }

    let mut pair = storage.pairs.get(pool).try_read().unwrap();
    pair.asset0.amount = balance0;
    pair.asset1.amount = balance1;
    storage.pairs.insert(pool, pair);
    storage.block_timestamp_last.insert(pool, block_timestamp);

    log(SyncEvent {
        reserve0: reserve0,
        reserve1: reserve1
    });
}


#[storage(read, write)]
fn mint_fee(pool: AssetId, asset0: AssetId, asset1: AssetId, reserve0: u64, reserve1: u64) -> bool {
    let factory_contract_id = storage.factory.read();
    let factory_bits = factory_contract_id.into();
    let factory_contract = abi(Factory, factory_bits);
    require(factory_contract.check_asset_registry(pool, asset0, asset1), BaseError::InvalidPairAssetId);

    let fee_to = factory_contract.fee_to();
    let fee_on = !fee_to.is_zero();
    let mut k = storage.k_last.get(pool).try_read().unwrap_or(U128::zero());

    if fee_on {
        if !k.is_zero() {
            let root_k = sqrt(U128::from((0, reserve0))) * U128::from((0, reserve1));
            let root_k_last = sqrt(k);
            if root_k > root_k_last {
                let total_supply = storage.total_supply.get(pool).try_read().unwrap_or(0);
                let numerator = U128::from((0, total_supply)) * (root_k - root_k_last);
                let denominator = root_k * U128::from((0, 5)) + root_k_last;
                let liquidity = numerator / denominator;

                if liquidity > U128::zero() {
                    let liqui = liquidity.as_u64().unwrap();
                    storage.total_supply.insert(pool, total_supply + liqui);
                    mint(keccak256((asset0, asset1)), liqui);
                    transfer(Identity::Address(fee_to), pool, liqui);
                }
            }

        }
    } else if !k.is_zero()  {
        storage.k_last.insert(pool, U128::zero());
    }

    fee_on
}


#[storage(read)]
fn check_asset_registry(pool: AssetId, asset0: AssetId, asset1: AssetId) {
    let factory_contract_id = storage.factory.read();
    let factory_bits = factory_contract_id.into();
    let factory_contract = abi(Factory, factory_bits);    
    require(factory_contract.check_asset_registry(pool, asset0, asset1), BaseError::InvalidPairAssetId);
}