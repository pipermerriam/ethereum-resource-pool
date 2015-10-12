contract CallerPool {
        address operator;

        function CallerPool() {
                operator = msg.sender;
        }

        /*
         *  Caller bonding
         */
        mapping (address => uint) public callerBonds;

        function getMinimumBond() constant returns (uint) {
                return tx.gasprice * block.gaslimit;
        }

        function _deductFromBond(address callerAddress, uint value) internal {
                /*
                 *  deduct funds from a bond value without risk of an
                 *  underflow.
                 */
                if (value > callerBonds[callerAddress]) {
                        // Prevent Underflow.
                        __throw();
                }
                callerBonds[callerAddress] -= value;
        }

        function _addToBond(address callerAddress, uint value) internal {
                /*
                 *  Add funds to a bond value without risk of an
                 *  overflow.
                 */
                if (callerBonds[callerAddress] + value < callerBonds[callerAddress]) {
                        // Prevent Overflow
                        __throw();
                }
                callerBonds[callerAddress] += value;
        }

        function depositBond() public {
                _addToBond(msg.sender, msg.value);
        }

        function withdrawBond(uint value) public {
                /*
                 *  Only if you are not in either of the current call pools.
                 */
                if (isInAnyPool(msg.sender)) {
                        // Prevent underflow
                        if (value > callerBonds[msg.sender]) {
                                __throw();
                        }
                        // Don't allow withdrawl if this would drop the bond
                        // balance below the minimum.
                        if (callerBonds[msg.sender] - value < getMinimumBond()) {
                                return;
                        }
                }
                _deductFromBond(msg.sender, value);
                if (!msg.sender.send(value)) {
                        // Potentially sending money to a contract that
                        // has a fallback function.  So instead, try
                        // tranferring the funds with the call api.
                        if (!msg.sender.call.gas(msg.gas).value(value)()) {
                                // Revert the entire transaction.  No
                                // need to destroy the funds.
                                __throw();
                        }
                }
        }

        function() {
                /*
                 *  Fallback function that allows depositing bond funds just by
                 *  sending a transaction.
                 */
                _addToBond(msg.sender, msg.value);
        }

        /*
         *  API used by Alarm service
         */
        function getDesignatedCaller(bytes32 callKey, uint targetBlock, uint8 gracePeriod, uint blockNumber) constant returns (address) {
                /*
                 *  Returns the caller from the current call pool who is
                 *  designated as the executor of this call.
                 */
                if (blockNumber < targetBlock || blockNumber > targetBlock + gracePeriod) {
                        // blockNumber not within call window.
                        return 0x0;
                }

                // Pool used is based on the starting block for the call.  This
                // allows us to know that the pool cannot change for at least
                // POOL_FREEZE_NUM_BLOCKS which is kept greater than the max
                // grace period.
                uint poolNumber = getPoolKeyForBlock(targetBlock);
                if (poolNumber == 0) {
                        // No pool currently in operation.
                        return 0x0;
                }
                var pool = callerPools[poolNumber];

                uint numWindows = gracePeriod / 4;
                uint blockWindow = (blockNumber - targetBlock) / 4;

                if (blockWindow + 2 > numWindows) {
                        // We are within the free-for-all period.
                        return 0x0;
                }

                uint offset = uint(callKey) % pool.length;
                return pool[(offset + blockWindow) % pool.length];
        }

        event AwardedMissedBlockBonus(address indexed fromCaller, address indexed toCaller, uint indexed poolNumber, bytes32 callKey, uint blockNumber, uint bonusAmount);

        function _doBondBonusTransfer(address fromCaller, address toCaller) internal returns (uint) {
                uint bonusAmount = getMinimumBond();
                uint bondBalance = callerBonds[fromCaller];

                // If the bond balance is lower than the award
                // balance, then adjust the reward amount to
                // match the bond balance.
                if (bonusAmount > bondBalance) {
                        bonusAmount = bondBalance;
                }

                // Transfer the funds fromCaller => toCaller
                _deductFromBond(fromCaller, bonusAmount);
                _addToBond(toCaller, bonusAmount);

                return bonusAmount;
        }

        function awardMissedBlockBonus(address toCaller, bytes32 callKey, uint targetBlock, uint8 gracePeriod) public {
                if (msg.sender != operator) {
                        return;
                }

                uint poolNumber = getPoolKeyForBlock(targetBlock);
                var pool = callerPools[poolNumber];
                uint i;
                uint bonusAmount;
                address fromCaller;

                uint numWindows = gracePeriod / 4;
                uint blockWindow = (block.number - targetBlock) / 4;

                // Check if we are within the free-for-all period.  If so, we
                // award from all pool members.
                if (blockWindow + 2 > numWindows) {
                        address firstCaller = getDesignatedCaller(callKey, targetBlock, gracePeriod, targetBlock);
                        for (i = targetBlock; i <= targetBlock + gracePeriod; i += 4) {
                                fromCaller = getDesignatedCaller(callKey, targetBlock, gracePeriod, i);
                                if (fromCaller == firstCaller && i != targetBlock) {
                                        // We have already gone through all of
                                        // the pool callers so we should break
                                        // out of the loop.
                                        break;
                                }
                                if (fromCaller == toCaller) {
                                        continue;
                                }
                                bonusAmount = _doBondBonusTransfer(fromCaller, toCaller);

                                // Log the bonus was awarded.
                                AwardedMissedBlockBonus(fromCaller, toCaller, poolNumber, callKey, block.number, bonusAmount);
                        }
                        return;
                }

                // Special case for single member and empty pools
                if (pool.length < 2) {
                        return;
                }

                // Otherwise the award comes from the previous caller.
                for (i = 0; i < pool.length; i++) {
                        // Find where the member is in the pool and
                        // award from the previous pool members bond.
                        if (pool[i] == toCaller) {
                                fromCaller = pool[(i + pool.length - 1) % pool.length];

                                bonusAmount = _doBondBonusTransfer(fromCaller, toCaller);

                                // Log the bonus was awarded.
                                AwardedMissedBlockBonus(fromCaller, toCaller, poolNumber, callKey, block.number, bonusAmount);

                                // Remove the caller from the next pool.
                                if (getNextPoolKey() == 0) {
                                        // This is the first address to modify the
                                        // current pool so we need to setup the next
                                        // pool.
                                        _initiateNextPool();
                                }
                                _removeFromPool(fromCaller, getNextPoolKey());
                                return;
                        }
                }
        }

        /*
         *  Caller Pool Management
         */
        uint[] public poolHistory;
        mapping (uint => address[]) callerPools;

        function getPoolKeyForBlock(uint blockNumber) constant returns (uint) {
                if (poolHistory.length == 0) {
                        return 0;
                }
                for (uint i = 0; i < poolHistory.length; i++) {
                        uint poolStartBlock = poolHistory[poolHistory.length - i - 1];
                        if (poolStartBlock <= blockNumber) {
                                return poolStartBlock;
                        }
                }
                return 0;
        }

        function getActivePoolKey() constant returns (uint) {
                return getPoolKeyForBlock(block.number);
        }

        function getPoolSize(uint poolKey) constant returns (uint) {
                return callerPools[poolKey].length;
        }

        function getNextPoolKey() constant returns (uint) {
                if (poolHistory.length == 0) {
                        return 0;
                }
                uint latestPool = poolHistory[poolHistory.length - 1];
                if (latestPool > block.number) {
                        return latestPool;
                }
                return 0;
        }

        function isInAnyPool(address callerAddress) constant returns (bool) {
                /*
                 *  Returns boolean whether the `callerAddress` is in either
                 *  the current active pool or the next pool.
                 */
                return isInPool(msg.sender, getActivePoolKey()) || isInPool(msg.sender, getNextPoolKey());
        }

        function isInPool(address callerAddress, uint poolNumber) constant returns (bool) {
                /*
                 *  Returns boolean whether the `callerAddress` is in the
                 *  poolNumber.
                 */
                if (poolNumber == 0 ) {
                        // Nobody can be in pool 0
                        return false;
                }

                var pool = callerPools[poolNumber];

                // Nobody is in the pool.
                if (pool.length == 0) {
                        return false;
                }

                for (uint i = 0; i < pool.length; i++) {
                        // Address is in the pool and thus is allowed to exit.
                        if (pool[i] == callerAddress) {
                                return true;
                        }
                }

                return false;
        }

        // Ten minutes into the future.
        uint constant POOL_FREEZE_NUM_BLOCKS = 256;

        function getPoolFreezeDuration() constant returns (uint) {
                return POOL_FREEZE_NUM_BLOCKS;
        }

        function getPoolMinimumLength() constant returns (uint) {
                return 2 * POOL_FREEZE_NUM_BLOCKS;
        }

        function canEnterPool(address callerAddress) constant returns (bool) {
                /*
                 *  Returns boolean whether `callerAddress` is allowed to enter
                 *  the next pool (which may or may not already have been
                 *  created.
                 */
                // Not allowed to join if you are in either the current
                // active pool or the next pool.
                if (isInAnyPool(callerAddress)) {
                        return false;
                }

                // Next pool begins within the POOL_FREEZE_NUM_BLOCKS grace
                // period so no changes are allowed.
                if (getNextPoolKey() != 0 && block.number >= (getNextPoolKey() - POOL_FREEZE_NUM_BLOCKS)) {
                        return false;
                }

                // Account bond balance is too low.
                if (callerBonds[callerAddress] < getMinimumBond()) {
                        return false;
                }
                
                return true;
        }

        function canExitPool(address callerAddress) constant returns (bool) {
                /*
                 *  Returns boolean whether `callerAddress` is allowed to exit
                 *  the current active pool.
                 */
                // Can't exit if we aren't in the current active pool.
                if (!isInPool(callerAddress, getActivePoolKey())) {
                        return false;
                }

                // There is a next pool coming up.
                if (getNextPoolKey() != 0) {
                        // Next pool begins within the POOL_FREEZE_NUM_BLOCKS
                        // window and thus can't be modified.
                        if (block.number >= (getNextPoolKey() - POOL_FREEZE_NUM_BLOCKS)) {
                                return false;
                        }

                        // Next pool was already setup and callerAddress isn't
                        // in it which indicates that they already left.
                        if (!isInPool(callerAddress, getNextPoolKey())) {
                                return false;
                        }
                }

                // They must be in the current pool and either the next pool
                // hasn't been initiated or it has but this user hasn't left
                // yet.
                return true;
        }

        function _initiateNextPool() internal {
                if (getNextPoolKey() != 0) {
                        // If there is already a next pool, we shouldn't
                        // initiate a new one until it has become active.
                        __throw();
                }
                // Set the next pool to start at double the freeze block number
                // in the future.
                uint nextPool = block.number + 2 * POOL_FREEZE_NUM_BLOCKS;

                // Copy the current pool into the next pool.
                callerPools[nextPool] = callerPools[getActivePoolKey()];

                // Randomize the pool order
                _shufflePool(nextPool);

                // Push the next pool into the pool history.
                poolHistory.length += 1;
                poolHistory[poolHistory.length - 1] = nextPool;
        }

        function _shufflePool(uint poolNumber) internal {
                var pool = callerPools[poolNumber];

                uint swapIndex;
                address buffer;

                for (uint i = 0; i < pool.length; i++) {
                        swapIndex = uint(sha3(block.blockhash(block.number), i)) % pool.length;
                        if (swapIndex == i) {
                                continue;
                        }
                        buffer = pool[i];
                        pool[i] = pool[swapIndex];
                        pool[swapIndex] = buffer;
                }
        }

        event AddedToPool(address indexed callerAddress, uint indexed pool);
        event RemovedFromPool(address indexed callerAddress, uint indexed pool);

        function _addToPool(address callerAddress, uint poolNumber) internal {
                if (poolNumber == 0 ) {
                        // This shouldn't be called with 0;
                        __throw();
                }

                // already in the pool.
                if (isInPool(callerAddress, poolNumber)) {
                        return;
                }
                var pool = callerPools[poolNumber];
                pool.length += 1;
                pool[pool.length - 1] = callerAddress;
                
                // Log the addition.
                AddedToPool(callerAddress, poolNumber);
        }

        function _removeFromPool(address callerAddress, uint poolNumber) internal {
                if (poolNumber == 0 ) {
                        // This shouldn't be called with 0;
                        __throw();
                }

                // nothing to remove.
                if (!isInPool(callerAddress, poolNumber)) {
                        return;
                }
                var pool = callerPools[poolNumber];
                // special case length == 1
                if (pool.length == 1) {
                        pool.length = 0;
                }
                for (uint i = 0; i < pool.length; i++) {
                        // When we find the index of the address to remove we
                        // shift the last person to that location and then we
                        // truncate the last member off of the end.
                        if (pool[i] == callerAddress) {
                                pool[i] = pool[pool.length - 1];
                                pool.length -= 1;
                                break;
                        }
                }

                // Log the addition.
                RemovedFromPool(callerAddress, poolNumber);
        }

        function enterPool() public {
                /*
                 *  Request to be added to the call pool.
                 */
                if (canEnterPool(msg.sender)) {
                        if (getNextPoolKey() == 0) {
                                // This is the first address to modify the
                                // current pool so we need to setup the next
                                // pool.
                                _initiateNextPool();
                        }
                        _addToPool(msg.sender, getNextPoolKey());
                }
        }

        function exitPool() public {
                /*
                 *  Request to be removed from the call pool.
                 */
                if (canExitPool(msg.sender)) {
                        if (getNextPoolKey() == 0) {
                                // This is the first address to modify the
                                // current pool so we need to setup the next
                                // pool.
                                _initiateNextPool();
                        }
                        _removeFromPool(msg.sender, getNextPoolKey());
                }
        }

        function __throw() internal {
                int[] x;
                x[1];
        }
}
