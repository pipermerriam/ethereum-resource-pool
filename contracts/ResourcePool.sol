import "libraries/ResourcePoolLib.sol";


contract ResourcePool {
        mapping (bytes32 => ResourcePoolLib.Pool) pools;
        mapping (bytes32 => bytes32) poolNames;

        // TODO: What features does the central contract support?
}
