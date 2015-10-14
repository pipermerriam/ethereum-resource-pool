def test_entering_pool(pool):
    # Should not be able to enter pool.
    assert pool.canEnterPool() is False

    # Ensure that it's because of the bond.
    assert pool.isInPool() is False
    assert pool.getNextGenerationId() == 0

    pool.depositBond(value=10)

    # Should now be able to enter the pool.
    assert pool.canEnterPool() is True

    pool.enterPool()

    # Should not be able to enter pool.
    assert pool.canEnterPool() is False

    # Ensure that it's because of the bond.
    assert pool.isInPool() is True
