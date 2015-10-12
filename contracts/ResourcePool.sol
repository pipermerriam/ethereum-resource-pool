// Resource Pool v0.1.0
import "libraries/Grove.sol";


// @title ResourcePool - A set of resources that are ready for use.
// @author Piper Merriam <pipermerriam@gmail.com>
library ResourcePoolLib {
        // Configuration


        struct Pool {
                uint _id;
                uint freezeDuration;

                GroveLib.Index generationStart;
                GroveLib.Index generationEnd;

                mapping (uint => Generation) generations;
                mapping (address => uint) bonds;
        }

        /*
         * Generations have the following properties.
         *
         * 1. Must always overlap by a minimum amount specified by MIN_OVERLAP.
         * 2. Each generation 
         *
         *    1   2   3   4   5   6   7   8   9   10  11  12  13
         *    [1:-----------------]
         *                [4:-------------]
         *                         [6:---------------------->
         */
        struct Generation {
                uint id;
                uint startAt;
                uint endAt;
                address[] members;
        }

        uint constant OVERLAP_WINDOW = 256;

        function spawnGeneration(Pool storage self) internal returns (Generation) {
                /*
                 *  - generate a "gap" generation that spans the transition.
                 *  - generate the next generation as open ended.
                 *  - copy all members into both.
                 */
                uint previousGenerationNodeId = GroveLib.query(self.generationStart, "<=", block.number);
                if (previousGenerationNodeId == 0x0) {
                        // This is the first generation.
                        self._id += 1;
                        Generation storage nextGeneration = self.generations[self._id];
                        nextGeneration.id = self._id;
                        nextGeneration.startAt = block.number + OVERLAP_WINDOW;
                        return nextGeneration;
                }

                address[] memory previousGenerationMembers = self.generations[self._id].members;

                self._id += 1;
                Generation storage gapGeneration = self.generations[self._id];
        }

        function getActiveGeneration() constant returns (uint) {
        }

        function getGenerationForWindow(Pool storage self, uint leftBound, uint rightBound) constant returns (uint) {
                int left = GroveLib.query(self.generationStart, "<=", leftBound);
                int right = GroveLib.query(self.generationEnd, ">=", rightBound);

                if (leftBound == 0x0) {
                        // There is no generation that satisfies this query
                        return 0;
                }
                if (leftBound == rightBound || rightBound == 0x0) {
                        // - if equal, then there is alread a *next*
                        // generation, but it isn't active yet.  If right is
                        // null, then the generation denoted by leftBound has
                        // not had it's end set.
                        return GroveLib.getNodeId(self.generationStart, left);
                }
                return GroveLib.getNodeId(self.generationEnd, right);
        }


        function canEnterPool(address resourceAddress, bytes32 generationId) constant returns (bool);
        function enterPool(bytes32 generationId) public;
        function onPoolEntered(address resourceAddress, bytes32 generationId) internal;

        function canExitPool(address resourceAddress, bytes32 generationId) constant returns (bool);
        function exitPool(bytes32 generationId) public;
        function onPoolExited(address resourceAddress, bytes32 generationId) internal;

        /*
         *  Bonding
         */

        function getMinimumBond() constant returns (uint);

        function _deductFromBond(Pool storage self, address resourceAddress, uint value) internal {
                /*
                 *  deduct funds from a bond value without risk of an
                 *  underflow.
                 */
                if (value > self.bonds[resourceAddress]) {
                        // Prevent Underflow.
                        throw;
                }
                self.bonds[resourceAddress] -= value;
        }

        function _addToBond(Pool storage self, address resourceAddress, uint value) internal {
                /*
                 *  Add funds to a bond value without risk of an
                 *  overflow.
                 */
                if (self.bonds[resourceAddress] + value < self.bonds[resourceAddress]) {
                        // Prevent Overflow
                        throw;
                }
                self.bonds[resourceAddress] += value;
        }

        function depositBond(Pool storage self) public {
                _addToBond(self, msg.sender, msg.value);
        }

        function canWithdrawBond(address resourceAddress, uint value) constant returns (bool);
        function withdrawBond(Pool storage self, uint value) public {
                /*
                 *  Only if you are not in either of the current call pools.
                 */
                // Prevent underflow
                if (value > self.bonds[msg.sender]) {
                        throw;
                }

                // Do a permissions check to be sure they can withdraw the
                // funds.
                if (!canWithdrawBond(msg.sender, value)) {
                        return;
                }

                _deductFromBond(self, msg.sender, value);
                if (!msg.sender.send(value)) {
                        // Potentially sending money to a contract that
                        // has a fallback function.  So instead, try
                        // tranferring the funds with the call api.
                        if (!msg.sender.call.gas(msg.gas).value(value)()) {
                                // Revert the entire transaction.  No
                                // need to destroy the funds.
                                throw;
                        }
                }
        }

        // TODO: this needs to be implemented in the sentinal contract.
        //function() {
        //        /*
        //         *  Fallback function that allows depositing bond funds just by
        //         *  sending a transaction.
        //         */
        //        _addToBond(msg.sender, msg.value);
        //}
}
