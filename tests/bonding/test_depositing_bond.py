def test_depositing_bond(deployed_contracts):
    pool = deployed_contracts.ExampleResourcePool

    assert pool.getBondBalance() == 0

    txn_h = pool.depositBond(value=123)

    assert pool.getBondBalance() == 123

    pool.depositBond(value=456)

    assert pool.getBondBalance() == 579
