import "libraries/ResourcePoolLib.sol";


contract ExampleResourcePool {
        ResourcePoolLib.Pool pool;

        function ExampleResourcePool() {
            pool.overlapSize = 40;
            pool.freezePeriod = 40;
            pool.rotationDelay = 40;
            pool.minimumBond = 1 ether;
        }

        function getMinimumBond() constant returns (uint) {
                return pool.minimumBond;
        }

        function getBondBalance() constant returns (uint) {
                return getBondBalance(msg.sender);
        }

        function getBondBalance(address resourceAddress) constant returns (uint) {
                return pool.bonds[resourceAddress];
        }

        function depositBond() public {
                ResourcePoolLib._addToBond(pool, msg.sender, msg.value);
        }

        function canWithdrawBond(uint value) constant returns (bool) {
                return canWithdrawBond(msg.sender, value);
        }

        function canWithdrawBond(address resourceAddress, uint value) constant returns (bool) {
                return ResourcePoolLib.canWithdrawBond(pool, resourceAddress, value);
        }

        function withdrawBond(uint value) public {
                ResourcePoolLib.withdrawBond(pool, msg.sender, value);
        }
}
