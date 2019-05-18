pragma solidity ^0.5.2;

contract Factory {
    /*
     *  Events
     */
    event ContractInstantiation(address sender, address instantiation);

    /*
     *  Storage
     */
    mapping(address => bool) public isInstantiation;
    mapping(address => address[]) public instantiations;
    address[] public allInstantiations;

    /*
     * Public functions
     */
    function getAllInstantiationAt(uint256 i) public view returns (address) {
        require(i<allInstantiations.length, 'index is less than count');
        return allInstantiations[i];
    }
    function getAllInstantiationCount()
        public
        view
        returns (uint)
    {
        return allInstantiations.length;
    }
    function getInstantiationAt(address creator, uint256 i) public view returns (address) {
        require(i<instantiations[creator].length, 'index is less than count');
        return instantiations[creator][i];
    }

    /// @dev Returns number of instantiations by creator.
    /// @param creator Contract creator.
    /// @return Returns number of instantiations by creator.
    function getInstantiationCount(address creator)
        public
        view
        returns (uint)
    {
        return instantiations[creator].length;
    }

    /*
     * Internal functions
     */
    /// @dev Registers contract in factory registry.
    /// @param instantiation Address of contract instantiation.
    function register(address instantiation)
        internal
    {
        isInstantiation[instantiation] = true;
        instantiations[msg.sender].push(instantiation);
        allInstantiations.push(instantiation);
        emit ContractInstantiation(msg.sender, instantiation);
    }
}