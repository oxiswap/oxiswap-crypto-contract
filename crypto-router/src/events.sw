library;

pub struct DepositEvent {
    pub deposit_asset: AssetId,
    pub amount: u64
}


pub struct WithdrawEvent {
    pub withdraw_asset: AssetId,
    pub amount: u64
}