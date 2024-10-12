library;

pub enum RouterErr {
    Expired: (),
    Initialized: (),
    InvalidAssetId: (),
    InvalidPairAssetId: (),
    InvalidPath: (),
    InsufficientBalance: (),
    IdenticalAddresses: (),
    ZeroAddress: (),
    InsufficientAmount: (),
    InsufficientLiquidity: (),
    InsufficientInputAmount: (),
    InsufficientOutputAmount: (),
    InsufficientAmount0: (),
    InsufficientAmount1: (),
    ExcessiveInputAmount: (),
    SwapAmountTooHigh: u64,
}