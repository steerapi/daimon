pragma solidity ^0.5.2;

import "./Daimon.sol";
import "./Factory.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract DaimonFactory is Factory {
    using SafeMath for uint256;

    function create(
        string memory name, 
        string memory symbol, 
        uint8 decimals,
        uint256 problemDefinitionPeriodInSeconds,
        uint256 blockTimeInSeconds
    ) public returns (address daimonAddress) {
        Daimon daimon = new Daimon(name, symbol, decimals, problemDefinitionPeriodInSeconds, blockTimeInSeconds);
        daimonAddress = address(daimon);
        register(daimonAddress);
    }

}