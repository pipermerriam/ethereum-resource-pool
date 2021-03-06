def test_exiting_pool(pool, deploy_client):
    # Should not be able to exit since we aren't in a pool.
    assert pool.isInPool() is False
    assert pool.canExitPool() is False
    assert pool.getNextGenerationId() == 0

    pool.depositBond(value=10)

    # Should now be able to enter the pool.
    assert pool.canEnterPool() is True

    pool.enterPool()

    first_generation = pool.getNextGenerationId()

    assert first_generation > 0

    # Shouldnet be able to exit since it hasn't started yet.
    assert pool.canExitPool() is False
    assert pool.isInCurrentGeneration() is False

    # fastforward to the generation start
    [deploy_client.evm.mine() for _ in range(deploy_client.get_block_number(), pool.getGenerationStartAt(first_generation))]

    assert pool.isInCurrentGeneration() is True
    assert pool.canExitPool() is True

    # push a new generation into place.
    pool.createNextGeneration()

    second_generation = pool.getNextGenerationId()
    assert second_generation > first_generation

    freezes_at = pool.getGenerationStartAt(second_generation) - pool.getPoolFreezePeriod()

    # fastforward to just before the freeze.
    [deploy_client.evm.mine() for _ in range(deploy_client.get_block_number(), freezes_at - 1)]

    assert pool.canExitPool() is True
    # now step into the freeze window
    deploy_client.evm.mine()
    assert pool.canExitPool() is False

    # fastforward to just before generation starts
    [deploy_client.evm.mine() for _ in range(deploy_client.get_block_number(), pool.getGenerationStartAt(second_generation) - 1)]

    assert pool.canExitPool() is False
    # now step into generation
    deploy_client.evm.mine()
    assert pool.canExitPool() is True

    # now actually exit the pool
    pool.exitPool()

    third_generation = pool.getNextGenerationId()
    assert third_generation > second_generation

    assert pool.isInCurrentGeneration() is True
    assert pool.isInNextGeneration() is False

    # fast forward to third generation
    [deploy_client.evm.mine() for _ in range(deploy_client.get_block_number(), pool.getGenerationEndAt(second_generation) + 1)]

    assert pool.isInCurrentGeneration() is False
    assert pool.isInNextGeneration() is False
