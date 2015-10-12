import pytest

from ethereum.tester import TransactionFailed


def test_withdrawing_bond_rejects_invalid_amount(deployed_contracts):
    pool = deployed_contracts.ExampleResourcePool

    assert pool.getBondBalance() == 0
    txn_h = pool.depositBond(value=123)
    assert pool.getBondBalance() == 123

    ss = pool._meta.rpc_client.evm.snapshot()

    assert pool.canWithdrawBond(1) is True

    with pytest.raises(TransactionFailed):
        pool.withdrawBond(124)
