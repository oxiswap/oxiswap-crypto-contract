library;

pub enum BaseError {
    Initialized: (),
    Overflow: (),
    InsufficientLiquidityMinted: (),
    InsufficientLiquidityBurned: (),
    InsufficientOutputAmount: (),
    InsufficientLiquidity: (),
    InvalidTo: (),
    InsufficientPairInputAmount: (),
    K: (),
    Forbidden: (),
    InvalidPairAssetId: (),
}