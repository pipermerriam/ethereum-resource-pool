// Resource Pool v0.1.0
import "libraries/GroveLib.sol";
import "libraries/StringLib.sol";


// @title ResourcePoolLib - Library for a set of resources that are ready for use.
// @author Piper Merriam <pipermerriam@gmail.com>
library ResourcePoolLib {
        struct Pool {
                uint rotationDelay;
                uint overlapSize;
                uint minimumBond;

                uint _id;

                GroveLib.Index generationStart;
                GroveLib.Index generationEnd;

                mapping (uint => Generation) generations;
                mapping (address => uint) bonds;
        }

        /*
         * Generations have the following properties.
         *
         * 1. Must always overlap by a minimum amount specified by MIN_OVERLAP.
         *
         *    1   2   3   4   5   6   7   8   9   10  11  12  13
         *    [1:-----------------]
         *                [4:--------------------->
         */
        struct Generation {
                uint id;
                uint startAt;
                uint endAt;
                address[] members;
        }

        function _spawnGeneration(Pool storage self) internal returns (Generation) {
                /*
                 *  Spawns a new pool generation with all of the current
                 *  generation's members copied over in random order.
                 */
                var previousGeneration = self.generations[self._id];

                self._id += 1;
                Generation storage nextGeneration = self.generations[self._id];
                nextGeneration.id = self._id;
                nextGeneration.startAt = block.number + self.rotationDelay;

                if (previousGeneration.id == 0) {
                        // This is the first generation so we just need to set
                        // it's `id` and `startAt`.
                        return nextGeneration;
                }

                // Set the end date for the current generation.
                previousGeneration.endAt = block.number + self.rotationDelay + self.overlapSize;

                // Now we copy the members of the previous generation over to
                // the next generation as well as randomizing their order.
                address[] memory members = previousGeneration.members;

                for (uint i = 0; i < members.length; i++) {
                    // Pick a *random* index and push it onto the next
                    // generation's members.
                    uint index = uint(sha3(block.blockhash(block.number))) % (nextGeneration.members.length - members.length);
                    nextGeneration.members.length += 1;
                    nextGeneration.members[nextGeneration.members.length - 1] = members[index];

                    // Then move the member at the last index into the picked
                    // index's location.
                    members[index] = members[members.length - 1];
                }

                return nextGeneration;
        }

        function getGenerationForWindow(Pool storage self, uint leftBound, uint rightBound) constant returns (uint) {
                var left = GroveLib.query(self.generationStart, "<=", int(leftBound));
                var right = GroveLib.query(self.generationEnd, ">=", int(rightBound));

                if (leftBound == 0x0) {
                        // There is no generation that satisfies this query
                        return 0;
                }
                if (leftBound == rightBound || rightBound == 0x0) {
                        // - if equal, then there is alread a *next*
                        // generation, but it isn't active yet.  If right is
                        // null, then the generation denoted by leftBound has
                        // not had it's end set.
                        return StringLib.bytesToUInt(GroveLib.getNodeId(self.generationStart, left));
                }
                return StringLib.bytesToUInt(GroveLib.getNodeId(self.generationEnd, right));
        }


        function canEnterPool(address resourceAddress, bytes32 generationId) constant returns (bool);
        function enterPool(bytes32 generationId) public;

        function canExitPool(address resourceAddress, bytes32 generationId) constant returns (bool);
        function exitPool(bytes32 generationId) public;

        /*
         *  Bonding
         */

        function _deductFromBond(Pool storage self, address resourceAddress, uint value) {
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

        function _addToBond(Pool storage self, address resourceAddress, uint value) {
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

        function canWithdrawBond(Pool storage self, address resourceAddress, uint value) constant returns (bool) {
                // TODO: only allow withdrawl if not in any active or pending
                // pools.
                return false;
        }

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
                if (!canWithdrawBond(self, msg.sender, value)) {
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
}
