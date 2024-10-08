use fuels::{
    prelude::{abigen, AssetId, Address, ContractId, WalletUnlocked, TxPolicies, CallParameters, VariableOutputPolicy},
    programs::responses::CallResponse,
};

abigen!(
    Contract(
        name = "Factory",
        abi = "./crypto-factory/out/debug/crypto-factory-abi.json"
    ),
    Contract(
        name = "Pair",
        abi = "./crypto-pair/out/debug/crypto-pair-abi.json"
    ),
    Contract(
        name = "Router",
        abi = "./crypto-router/out/debug/crypto-router-abi.json"
    )
);


pub mod factory {
    use super::*;

    pub async fn constructor(contract: &Factory<WalletUnlocked>, fee_to: Address, pool: ContractId) -> CallResponse<()> {
        contract
            .methods()
            .constructor(fee_to, pool)
            .call()
            .await
            .unwrap()
    }


    pub async fn create_pair(contract: &Factory<WalletUnlocked>, token0: AssetId, token1: AssetId, pool_contract: &Pair<WalletUnlocked>) -> CallResponse<AssetId> {
        contract
            .methods()
            .create_pair(token0, token1)
            .with_contracts(&[pool_contract])
            .call()
            .await
            .unwrap()
    }
}


pub mod pair {
    use super::*;

    pub async fn constructor(contract: &Pair<WalletUnlocked>, factory: ContractId) -> CallResponse<()> {
        contract
            .methods()
            .constructor(factory)
            .call()
            .await
            .unwrap()
    }


    pub async fn mint(contract: &Pair<WalletUnlocked>, pool: AssetId, to: Address, amount0: u64, amount1: u64, factory_contract: &Factory<WalletUnlocked>) -> CallResponse<u64> {
        contract
            .methods()
            .mint(pool, to, amount0, amount1)
            .with_variable_output_policy(VariableOutputPolicy::Exactly(4))
            .with_contracts(&[factory_contract])
            .call()
            .await
            .unwrap()
    }


    pub async fn burn(contract: &Pair<WalletUnlocked>, pool: AssetId, to: Address, amount: u64, factory_contract: &Factory<WalletUnlocked>) -> CallResponse<(u64, u64)> {
        let tx_policies = TxPolicies::default();
        let call_param = CallParameters::new(amount, pool, 1_000_000);

        contract
            .methods()
            .burn(pool, to)
            .with_variable_output_policy(VariableOutputPolicy::Exactly(3))
            .with_contracts(&[factory_contract])
            .with_tx_policies(tx_policies)
            .call_params(call_param)
            .expect("burn")
            .call()
            .await
            .unwrap()
    }


    pub async fn swap(contract: &Pair<WalletUnlocked>, pool: AssetId, amount0_out: u64, amount1_out: u64, to: Address) -> CallResponse<()> {
        let tx_policies = TxPolicies::default();

        contract
            .methods()
            .swap(pool, amount0_out, amount1_out, to)
            .with_variable_output_policy(VariableOutputPolicy::Exactly(2))
            .with_tx_policies(tx_policies)
            .call()
            .await
            .unwrap()
    }
}


pub mod router {
    
    use super::*;

    pub async fn constructor(contract: &Router<WalletUnlocked>, factory_contract: ContractId, pool_contract: ContractId) -> CallResponse<()> {
        contract
            .methods()
            .constructor(factory_contract, pool_contract)
            .call()
            .await
            .unwrap()
    }


    pub async fn deposit(contract: &Router<WalletUnlocked>, asset: AssetId, amount: u64) -> CallResponse<bool> {
        let tx_policies = TxPolicies::default();
        let call_param = CallParameters::new(amount, asset, 1_000_000);

        contract
            .methods()
            .deposit()
            .with_tx_policies(tx_policies)
            .call_params(call_param)
            .expect("deposit")
            .call()
            .await
            .unwrap()
    }


    pub async fn withdraw(contract: &Router<WalletUnlocked>, asset: AssetId, amount: u64) -> CallResponse<bool> {
        contract
            .methods()
            .withdraw(asset, amount)
            .with_variable_output_policy(VariableOutputPolicy::Exactly(1))
            .call()
            .await
            .unwrap()
    }


    pub async fn add_liquidity(
        contract: &Router<WalletUnlocked>,
        pair_contract: &Pair<WalletUnlocked>,
        factory_contract: &Factory<WalletUnlocked>,
        asset0: AssetId,
        asset1: AssetId,
        amount0_desired: u64,
        amount1_desired: u64,
        amount0_min: u64,
        amount1_min: u64,
        to: Address,
        deadline: u64
    ) -> CallResponse<(u64, u64, u64)> {
        let tx_policies = TxPolicies::default().with_script_gas_limit(10_000_000);

        contract
            .methods()
            .add_liquidity(asset0, asset1, amount0_desired, amount1_desired, amount0_min, amount1_min, to, deadline)
            .with_variable_output_policy(VariableOutputPolicy::Exactly(6))
            .with_tx_policies(tx_policies)
            .with_contracts(&[pair_contract, factory_contract])
            .call()
            .await
            .unwrap()
    }


    pub async fn remove_liquidity(
        contract: &Router<WalletUnlocked>,
        pool: AssetId,
        pair_contract: &Pair<WalletUnlocked>,
        factory_contract: &Factory<WalletUnlocked>,
        asset0: AssetId,
        asset1: AssetId,
        liquidity: u64,
        amount0_min: u64,
        amount1_min: u64,
        to: Address,
        deadline: u64
    ) -> CallResponse<(u64, u64)> {
        let tx_policies = TxPolicies::default();
        let call_param = CallParameters::new(liquidity, pool, 1_000_000);

        contract
            .methods()
            .remove_liquidity(asset0, asset1, liquidity, amount0_min, amount1_min, to, deadline)
            .with_variable_output_policy(VariableOutputPolicy::Exactly(3))
            .with_contracts(&[pair_contract, factory_contract])
            .with_tx_policies(tx_policies)
            .call_params(call_param)
            .expect("remove")
            .call()
            .await
            .unwrap()
    }


    pub async fn swap_exact_input(
        contract: &Router<WalletUnlocked>,
        pair_contract: &Pair<WalletUnlocked>,
        amount_in: u64,
        amount_out_min: u64,
        path: Vec<AssetId>,
        to: Address,
        deadline: u64
    ) -> CallResponse<Vec<u64>> {
        let tx_policies = TxPolicies::default();
        let call_param = CallParameters::new(amount_in, path[0], 1_000_000);

        contract
            .methods()
            .swap_exact_input(amount_in, amount_out_min, path, to, deadline)
            .with_variable_output_policy(VariableOutputPolicy::Exactly(3))
            .with_contracts(&[pair_contract])
            .with_tx_policies(tx_policies)
            .call_params(call_param)
            .expect("swap")
            .call()
            .await
            .unwrap()
    }


    pub async fn swap_exact_output(
        contract: &Router<WalletUnlocked>,
        pair_contract: &Pair<WalletUnlocked>,
        amount_out: u64,
        amount_in_max: u64,
        path: Vec<AssetId>,
        to: Address,
        deadline: u64
    ) -> CallResponse<Vec<u64>> {
        let tx_policies = TxPolicies::default();
        let call_param = CallParameters::new(amount_in_max, path[0], 1_000_000);

        contract
            .methods()
            .swap_exact_output(amount_out, amount_in_max, path, to, deadline)
            .with_variable_output_policy(VariableOutputPolicy::Exactly(3))
            .with_contracts(&[pair_contract])
            .with_tx_policies(tx_policies)
            .call_params(call_param)
            .expect("swap")
            .call()
            .await
            .unwrap()
    }
}