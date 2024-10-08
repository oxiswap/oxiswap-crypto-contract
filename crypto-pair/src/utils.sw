library;

use std::u128::U128;
use core::primitives::*;

pub fn encode_q128(y: u64) -> U128 {
    let Q128: U128 = U128::from((0, u64::max()));
    U128::from((0, y)) * Q128
}


pub fn uqdiv_q128(x: U128, y: u64) -> U128 {
    x / U128::from((0, y))
}


pub fn min(x: U128, y: U128) -> U128 {
    if x < y { x } else { y }
}


pub fn sqrt(y: U128) -> U128 {
    let mut z: U128 = U128::zero();
    if (y > U128::from((0, 3))) {
        z = y;
        let mut x: U128 = y / U128::from((0, 2)) + U128::from((0, 1));
        while (x < z) {
            z = x;
            x = (y / x + x) / U128::from((0, 2));
        }
    } else if (y != U128::zero()) {
        z = U128::from((0, 1))
    }

    z
}


pub struct Asset {
    pub id: AssetId,
    pub amount: u64,
}


impl Asset {
    pub fn new(id: AssetId, amount: u64) -> Self {
        Self { id, amount }
    }


    pub fn default() -> Self {
        Self { 
            id: AssetId::zero(), 
            amount: 0,
        }
    }
} 


pub struct AssetPair {
    pub asset0: Asset,
    pub asset1: Asset,
}


impl AssetPair {
    pub fn new(asset0: Asset, asset1: Asset) -> Self {
        Self { asset0, asset1 }
    }


    pub fn ids(self) -> (AssetId, AssetId) {
        (self.asset0.id, self.asset1.id)
    }


    pub fn amounts(self) -> (u64, u64) {
        (self.asset0.amount, self.asset1.amount)
    }


    pub fn default() -> Self {
        Self {
            asset0: Asset::default(),
            asset1: Asset::default(),
        }
    }
}

