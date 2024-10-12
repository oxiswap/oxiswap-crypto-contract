contract;

mod errors;
mod events;

use errors::*;
use events::*;

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
    }
};

use libraries::{Pair, Factory, Router};


configurable {
    ETH: AssetId = AssetId::from(0xf8f8b6283d7fa5b672b530cbb84fcccb4ff8dc40f8176ef4544ddb1f1952ad07)
}

storage {
    factory: ContractId = ContractId::zero(),
    pool: ContractId = ContractId::zero(),
    owner: Address = Address::zero(),
    is_initialized: bool = false,
    deposits: StorageMap<(Identity, AssetId), u64> = StorageMap {},
}


impl Router for Contract {
    #[storage(read)]
    fn get_factory() -> ContractId {
        storage.factory.read()
    }


    #[storage(read)]
    fn quote(amount0: u64, reserve0: u64, reserve1: u64) -> u64 {
        quote_internal(amount0, reserve0, reserve1)
    }


    #[storage(read)]
    fn get_amounts_out(amount_in: u64, path: Vec<AssetId>) -> Vec<u64> {
        get_amounts_out_internal(amount_in, path)
    }


    #[storage(read)]
    fn get_amounts_in(amount_out: u64, path: Vec<AssetId>) -> Vec<u64> {
        get_amounts_in_internal(amount_out, path)
    }


    #[storage(read)]
    fn get_deposits(sender: Identity, asset: AssetId) -> u64 {
        storage.deposits.get((sender, asset)).try_read().unwrap_or(0)
    }


    #[storage(read, write)]
    fn constructor(factory: ContractId, pool: ContractId) {
        require(!storage.is_initialized.read(), RouterErr::Initialized);

        storage.owner.write(msg_sender().unwrap().as_address().unwrap());
        storage.factory.write(factory);
        storage.pool.write(pool);
        storage.is_initialized.write(true);
    }


    #[payable, storage(read, write)]
    fn deposit() -> bool {
        let deposit_asset = msg_asset_id();
        let sender = msg_sender().unwrap();
        let amount = msg_amount();

        let new_deposited = storage.deposits.get((sender, deposit_asset)).try_read().unwrap_or(0) + amount;
        storage.deposits.insert((sender, deposit_asset), new_deposited);

        log(DepositEvent {
            deposit_asset: deposit_asset,
            amount: amount
        });

        true
    }


    #[storage(read, write)]
    fn withdraw(asset_id: AssetId, amount: u64) -> bool {
        let sender = msg_sender().unwrap();
        let old_deposit = storage.deposits.get((sender, asset_id)).try_read().unwrap_or(0);
        require(old_deposit >= amount, RouterErr::InsufficientBalance);

        let new_deposit = old_deposit - amount;
        if new_deposit != old_deposit {
            storage.deposits.insert((sender, asset_id), new_deposit);
        }
        
        transfer(sender, asset_id, amount);

        log(WithdrawEvent {
            withdraw_asset: asset_id,
            amount: amount
        });

        true
    }


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
    ) -> (u64, u64, u64) {
        ensure(deadline);
        let (new_asset0, new_asset1) = sort_assets(asset0, asset1);
        let (amount0, amount1) = add_liquidity_internal(
            asset0,
            asset1,
            if asset0 == new_asset0 { amount0_desired } else { amount1_desired },
            if asset0 == new_asset0 { amount1_desired } else { amount0_desired },
            if asset0 == new_asset0 { amount0_min } else { amount1_min },
            if asset0 == new_asset0 { amount1_min } else { amount0_min }
        );
        
        let pair = pair_for(new_asset0, new_asset1);
        let sender = msg_sender().unwrap();
        let amount0_deposit = storage.deposits.get((sender, new_asset0)).try_read().unwrap_or(0);
        let amount1_deposit = storage.deposits.get((sender, new_asset1)).try_read().unwrap_or(0);
        
        require(amount0_deposit >= amount0 && amount1_deposit >= amount1, RouterErr::InsufficientBalance);
        
        let pool = Identity::ContractId(storage.pool.read());
        transfer(pool, new_asset0, amount0);
        transfer(pool, new_asset1, amount1);

        let pool_contract = abi(Pair, pool.bits());
        let liquidity = pool_contract.mint(pair, to, amount0, amount1);

        (amount0, amount1, liquidity)
    }


    #[payable, storage(read, write)]
    fn remove_liquidity(
        asset0: AssetId,
        asset1: AssetId,
        liquidity: u64,
        amount0_min: u64,
        amount1_min: u64,
        to: Identity,
        deadline: u64
    ) -> (u64, u64) {
        ensure(deadline);
        let amount = msg_amount();
        require(liquidity == amount, RouterErr::InsufficientAmount);

        let (new_asset0, new_asset1) = sort_assets(asset0, asset1);
        let pair = pair_for(new_asset0, new_asset1);
        let pool = storage.pool.read();
        let pool_contract = abi(Pair, pool.bits());
        transfer(Identity::ContractId(pool), pair, amount);
        
        let (amount0, amount1) = pool_contract.burn(pair, to);
        let (new_amount0, new_amount1) = if asset0.bits() == new_asset0.bits() {
            (amount0, amount1)
        } else {
            (amount1, amount0)
        };
        require(new_amount0 >= amount0_min, RouterErr::InsufficientAmount0);
        require(new_amount1 >= amount1_min, RouterErr::InsufficientAmount1);

        (new_amount0, new_amount1)
    }


    #[payable, storage(read, write)]
    fn swap_exact_input(
        amount_in: u64,
        amount_out_min: u64,
        path: Vec<AssetId>,
        to: Identity,
        deadline: u64
    ) -> Vec<u64> {
        ensure(deadline);
        require(msg_amount() == amount_in, RouterErr::InsufficientAmount);
        require(msg_asset_id() == path.get(0).unwrap(), RouterErr::InvalidAssetId);
        let amounts = get_amounts_out_internal(amount_in, path);
        require(amounts.get(amounts.len() - 1).unwrap() >= amount_out_min, RouterErr::InsufficientOutputAmount);
        transfer(Identity::ContractId(storage.pool.read()), path.get(0).unwrap(), amount_in);
        swap_internal(amounts, path, to);

        amounts
    }


    #[payable, storage(read, write)]
    fn swap_exact_output(
        amount_out: u64,
        amount_in_max: u64,
        path: Vec<AssetId>,
        to: Identity,
        deadline: u64
    ) -> Vec<u64> {
        ensure(deadline);
        let amounts = get_amounts_in_internal(amount_out, path);
        let sold = amounts.get(0).unwrap();
        let bought = msg_amount();

        require(sold <= amount_in_max, RouterErr::ExcessiveInputAmount);
        require(msg_asset_id() == path.get(0).unwrap(), RouterErr::InvalidAssetId);
        require(bought >= sold, RouterErr::SwapAmountTooHigh(bought));

        transfer(Identity::ContractId(storage.pool.read()), msg_asset_id(), sold);
        
        let refund = bought - sold;
        if refund > 0 {
            transfer(msg_sender().unwrap(), msg_asset_id(), refund);
        }

        swap_internal(amounts, path, to);
        
        amounts
    }

}


fn ensure(deadline: u64) {
    require(deadline >= timestamp(), RouterErr::Expired);
}


#[storage(read, write)]
fn add_liquidity_internal(
    asset0: AssetId,
    asset1: AssetId,
    amount0_desired: u64,
    amount1_desired: u64,
    amount0_min: u64,
    amount1_min: u64
) -> (u64, u64) {
    let factory_contract_id = storage.factory.read();
    let factory_bits = factory_contract_id.into();
    let factory_contract = abi(Factory, factory_bits);
    let pair_asset_id = factory_contract.get_pair(asset0, asset1);
    if pair_asset_id.is_zero() {
        factory_contract.create_pair(asset0, asset1);
    }

    let (reserve0, reserve1) = get_reserves(asset0, asset1);
    let mut new_amount0 = 0;
    let mut new_amount1 = 0;

    if reserve0 == 0 && reserve1 == 0 {
        new_amount0 = amount0_desired;
        new_amount1 = amount1_desired;
    } else {
        let amount1_optimal = quote_internal(amount0_desired, reserve0, reserve1);
        
        if amount1_optimal <= amount1_desired {
            require(amount1_optimal >= amount1_min, RouterErr::InsufficientAmount1);
            new_amount0 = amount0_desired;
            new_amount1 = amount1_optimal;
        } else {
            let amount0_optimal = quote_internal(amount1_desired, reserve1, reserve0);
            assert(amount0_optimal <= amount0_desired);
            require(amount0_optimal >= amount0_min, RouterErr::InsufficientAmount0);
            new_amount0 = amount0_optimal;
            new_amount1 = amount1_desired;
        }
    }
    
    (new_amount0, new_amount1)
}


#[storage(read, write)]
fn swap_internal(amounts: Vec<u64>, path: Vec<AssetId>, to: Identity) {
    let mut i = 0;
    while i < path.len() - 1 {
        let (input, output) = (path.get(i).unwrap(), path.get(i+1).unwrap());
        let (asset0, asset1) = sort_assets(input, output);
        let amount_out = amounts.get(i+1).unwrap();
        let input_b256: b256 = input.into();
        let asset0_b256: b256 = asset0.into();
        let (amount0_out, amount1_out) = if input_b256 == asset0_b256 {
            (0, amount_out)
        } else {
            (amount_out, 0)
        };

        let pool = storage.pool.read();
        let new_to = if i < path.len() - 2 {
            Identity::ContractId(pool) 
        } else {
            to
        };
        
        let pool_contract = abi(Pair, pool.bits());
        pool_contract.swap(pair_for(asset0, asset1), amount0_out, amount1_out, new_to);

        i += 1;
    }
}


fn sort_assets(asset0: AssetId, asset1: AssetId) -> (AssetId, AssetId) {
    let asset0_b256: b256 = asset0.into();
    let asset1_b256: b256 = asset1.into();
    require(asset0_b256 != asset1_b256, RouterErr::IdenticalAddresses);
    
    let (new_asset0, new_asset1) = if asset0_b256 < asset1_b256 {
        (asset0, asset1)
    } else {
        (asset1, asset0)
    };
    require(!new_asset0.is_zero(), RouterErr::ZeroAddress);

    (new_asset0, new_asset1)
}


#[storage(read)]
fn pair_for(asset0: AssetId, asset1: AssetId) -> AssetId {
    let salt = keccak256((asset0, asset1));
    let new_asset_id = sha256((storage.pool.read(), salt));
    AssetId::from(new_asset_id)
}


#[storage(read)]
fn get_reserves(asset0: AssetId, asset1: AssetId) -> (u64, u64) {
    let (new_asset0, new_asset1) = sort_assets(asset0, asset1);
    let pool_contract = abi(Pair, storage.pool.read().bits());
    let (reserve0, reserve1, _) = pool_contract.get_reserves(pair_for(new_asset0, new_asset1));
    
    let asset0_b256: b256 = asset0.into();
    let new_asset0_b256: b256 = new_asset0.into();

    if asset0_b256 == new_asset0_b256 {
        (reserve0, reserve1)
    } else {
        (reserve1, reserve0)
    }
}


fn quote_internal(amount0: u64, reserve0: u64, reserve1: u64) -> u64 {
    require(amount0 > 0, RouterErr::InsufficientAmount);
    require(reserve0 > 0 && reserve1 > 0, RouterErr::InsufficientLiquidity);

    (U128::from((0, amount0)) * U128::from((0, reserve1)) / U128::from((0, reserve0))).as_u64().unwrap()
}


fn get_amount_out(amount_in: u64, reserve_in: u64, reserve_out: u64) -> u64 {
    require(amount_in > 0, RouterErr::InsufficientInputAmount);
    require(reserve_in > 0 && reserve_out > 0, RouterErr::InsufficientLiquidity);
    let amount_in_with_fee = U128::from((0, amount_in)) * U128::from((0, 997));
    let numerator = amount_in_with_fee * U128::from((0, reserve_out));
    let denominator = U128::from((0, reserve_in)) * U128::from((0, 1000)) + amount_in_with_fee;

    (numerator / denominator).as_u64().unwrap()
}


fn get_amount_in(amount_out: u64, reserve_in: u64, reserve_out: u64) -> u64 {
    require(amount_out > 0, RouterErr::InsufficientInputAmount);
    require(reserve_in > 0 && reserve_out > 0, RouterErr::InsufficientLiquidity);
    let numerator = U128::from((0, reserve_in)) * U128::from((0, amount_out)) * U128::from((0, 1000));
    let denominator = (U128::from((0, reserve_out)) - U128::from((0, amount_out))) * U128::from((0, 997));
    
    (numerator / denominator).as_u64().unwrap() + 1
}


#[storage(read)]
fn get_amounts_out_internal(amount_in: u64, path: Vec<AssetId>) -> Vec<u64> {
    require(path.len() >= 2, RouterErr::InvalidPath);
    let mut amounts: Vec<u64> = Vec::new();
    amounts.push(amount_in);
    let mut i = 0;

    while i < path.len() - 1 {
        let (reserve_in , reserve_out) = get_reserves(path.get(i).unwrap(), path.get(i+1).unwrap());
        let amount_out = get_amount_out(amounts.get(i).unwrap(), reserve_in, reserve_out);
        amounts.push(amount_out);
        i += 1;
    }

    amounts
}


#[storage(read)]
fn get_amounts_in_internal(amount_out: u64, path: Vec<AssetId>) -> Vec<u64> {
    require(path.len() >= 2, RouterErr::InvalidPath);
    let mut amounts: Vec<u64> = Vec::new();
    let mut j = 0;

    while j < path.len() {
        amounts.push(0);
        j += 1;
    }

    amounts.set(path.len() - 1, amount_out);
    let mut i = path.len() - 1;

    while i > 0 {
        let (reserve_in, reserve_out) = get_reserves(path.get(i-1).unwrap(), path.get(i).unwrap());
        let amount_in = get_amount_in(amounts.get(i).unwrap(), reserve_in, reserve_out);
        amounts.set(i - 1, amount_in);
        i -= 1;
    }

    amounts
}

