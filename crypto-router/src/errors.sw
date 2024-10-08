library;

pub enum RouterErr {
    Expired: (),
    Initialized: (),
    InvalidAssetId: (),
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