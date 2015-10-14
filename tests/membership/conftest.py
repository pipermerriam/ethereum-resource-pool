import pytest


@pytest.fixture(scope="module")
def pool(deployed_contracts):
    p = deployed_contracts.ResourcePoolTester
    return p
