library;

pub enum FactoryErr {
    Initialized: (),
    IdenticalAddresses: (),
    PairExists: (),
    Forbidden: (),
    ZeroAddress: (),
}