def test_withdrawing_bond(deployed_contracts):
    pool = deployed_contracts.ExampleResourcePool

    assert pool.getBondBalance() == 0
    txn_h = pool.depositBond(value=123)
    assert pool.getBondBalance() == 123

    assert pool.canWithdrawBond(1) is True
    pool.withdrawBond(100)

    assert pool.getBondBalance() == 23

    pool.withdrawBond(23)

    assert pool.getBondBalance() == 0
