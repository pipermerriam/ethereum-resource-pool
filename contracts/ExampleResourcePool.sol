import "libraries/ResourcePoolLib.sol";


contract ExampleResourcePool {
        ResourcePoolLib.Pool pool;

        function ExampleResourcePool() {
            //pool.overlapSize = 40;
            //pool.rotationDelay = 40;
            //pool.minimumBond = 1 ether;
        }

        function() {
                /*
                 *  Fallback function that allows depositing bond funds just by
                 *  sending a transaction.
                 */
                ResourcePoolLib._addToBond(pool, msg.sender, msg.value);
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
                ResourcePoolLib._addToBond(pool, 0x0, 123);
        }

        function withdrawBond(uint value) public {
                ResourcePoolLib.withdrawBond(pool, value);
        }
}
