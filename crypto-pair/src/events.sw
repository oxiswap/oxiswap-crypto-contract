library;


pub struct MintEvent {
    pub sender: Identity,
    pub amount0: u64,
    pub amount1: u64,
}


pub struct BurnEvent {
    pub sender: Identity,
    pub amount0: u64,
    pub amount1: u64,
    pub to: Address,
}


pub struct SwapEvent {
    pub sender: Identity,
    pub amount0_in: u64,
    pub amount1_in: u64,
    pub amount0_out: u64,
    pub amount1_out: u64,
    pub to: Address,
}


pub struct SyncEvent {
    pub reserve0: u64,
    pub reserve1: u64,
}