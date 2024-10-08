# OxiSwap

OxiSwap is a Lightning-Fast DEX powered by Fuel. It allows users to swap tokens, provide liquidity, and earn fees.

## Key Components

1. Router Contract (`crypto-router`) - [Go to Router Contract](./crypto-router)
2. Factory Contract (`crypto-factory`) - [Go to Factory Contract](./crypto-factory)
3. Pair Contract (`crypto-pair`) - [Go to Pair Contract](./crypto-pair)

## Features

- Token swaps
- Liquidity provision
- Automated market making
- Fee collection

## Router Contract

The Router contract is the main entry point for users to interact with OxiSwap. It handles:

- Adding and removing liquidity
- Token swaps (exact input and exact output)
- Quote calculations
- Path-based multi-hop swaps

## Factory Contract

The Factory contract is responsible for:

- Creating new trading pairs
- Managing the list of all trading pairs
- Setting and updating fee parameters

## Pair Contract

The Pair contract implements the core AMM (Automated Market Maker) logic:

- Minting and burning liquidity tokens
- Executing swaps
- Maintaining reserves and price accumulators
- Implementing the constant product formula (x * y = k)

## Key Functions

### Router

- `add_liquidity`: Add liquidity to a trading pair
- `remove_liquidity`: Remove liquidity from a trading pair
- `swap_exact_input`: Swap a fixed input amount for a minimum output amount
- `swap_exact_output`: Swap a maximum input amount for a fixed output amount

### Factory

- `create_pair`: Create a new trading pair
- `get_pair`: Retrieve the asset ID for a trading pair
- `all_pairs_length`: Get the total number of trading pairs

### Pair

- `mint`: Mint liquidity tokens when adding liquidity
- `burn`: Burn liquidity tokens when removing liquidity
- `swap`: Execute a token swap
- `get_reserves`: Retrieve the current reserves of a trading pair


## Security

OxiSwap implements several security measures:

- Reentrancy protection
- Overflow checks
- Deadline checks for transactions
- Minimum liquidity requirements


## License

© 2024 Oxiswap Ltd. All rights reserved.