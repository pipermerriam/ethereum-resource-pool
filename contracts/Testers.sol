import "libraries/ResourcePoolLib.sol";


contract ResourcePoolTester {

        ResourcePoolLib.Pool pool;

        function ResourcePoolTester() {
            pool.overlapSize = 5;
            pool.freezePeriod = 7;
            pool.rotationDelay = 9;
            pool.minimumBond = 1 wei;
        }
        /*
         * Shortcuts
         */
        function createNextGeneration() public {
            ResourcePoolLib._createNextGeneration(pool);
        }

        function addAddressToGeneration(address resourceAddress, uint generationId) public {
            var generation = pool.generations[generationId];
            generation.members.length += 1;
            generation.members[generation.members.length - 1] = resourceAddress;
        }

        /*
         *  Meta information getters
         */
        function getGenerationStartAt(uint generationId) constant returns (uint) {
            return pool.generations[generationId].startAt;
        }

        function getGenerationEndAt(uint generationId) constant returns (uint) {
            return pool.generations[generationId].endAt;
        }

        function getGenerationMemberLength(uint generationId) constant returns (uint) {
            return pool.generations[generationId].members.length;
        }

        function getPoolId() constant returns (uint) {
            return pool._id;
        }

        function getPoolOverlapSize() constant returns (uint) {
            return pool.overlapSize;
        }

        function getPoolFreezePeriod() constant returns (uint) {
            return pool.freezePeriod;
        }

        function getPoolRotationDelay() constant returns (uint) {
            return pool.rotationDelay;
        }

        
        /*
         *  Entering and Exiting the pool
         */
        function canEnterPool() constant returns (bool) {
            return canEnterPool(msg.sender);
        }

        function canEnterPool(address resourceAddress) constant returns (bool) {
            return ResourcePoolLib.canEnterPool(pool, resourceAddress);
        }

        function enterPool() public {
            ResourcePoolLib.enterPool(pool, msg.sender);
        }

        function enterPool(address resourceAddress) public {
            ResourcePoolLib.enterPool(pool, resourceAddress);
        }

        function canExitPool() constant returns (bool) {
            return canExitPool(msg.sender);
        }

        function canExitPool(address resourceAddress) constant returns (bool) {
            return ResourcePoolLib.canExitPool(pool, resourceAddress);
        }

        function exitPool() public {
            ResourcePoolLib.exitPool(pool, msg.sender);
        }

        function exitPool(address resourceAddress) public {
            ResourcePoolLib.exitPool(pool, resourceAddress);
        }

        /*
         *  Pool Generation Information
         */
        function getCurrentGenerationId() constant returns (uint) {
            return ResourcePoolLib.getCurrentGenerationId(pool);
        }

        function getNextGenerationId() constant returns (uint) {
            return ResourcePoolLib.getNextGenerationId(pool);
        }

        /*
         *  Membership information.
         */
        function isInGeneration(address resourceAddress, uint generationId) constant returns (bool) {
            return ResourcePoolLib.isInGeneration(pool, resourceAddress, generationId);
        }

        function isInCurrentGeneration() constant returns (bool) {
            return ResourcePoolLib.isInCurrentGeneration(pool, msg.sender);
        }

        function isInCurrentGeneration(address resourceAddress) constant returns (bool) {
            return ResourcePoolLib.isInCurrentGeneration(pool, resourceAddress);
        }

        function isInNextGeneration() constant returns (bool) {
            return ResourcePoolLib.isInNextGeneration(pool, msg.sender);
        }

        function isInNextGeneration(address resourceAddress) constant returns (bool) {
            return ResourcePoolLib.isInNextGeneration(pool, resourceAddress);
        }

        function isInPool() constant returns (bool) {
            return isInPool(msg.sender);
        }

        function isInPool(address resourceAddress) constant returns (bool) {
            return ResourcePoolLib.isInPool(pool, resourceAddress);
        }

        
        /*
         *  Bonding
         */
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
