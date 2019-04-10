pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract ProblemToken is ERC20Mintable,ERC20Burnable,ERC20Pausable,ERC20Detailed,Ownable {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;
    
    uint256 private _multiplier;
    constructor (
        string memory name, 
        string memory symbol, 
        uint8 decimals
    ) ERC20Detailed(name, symbol, decimals) public {
        _multiplier = 10**(uint256(decimals));
    }

    function multiplier() public view returns (uint256) {
        return _multiplier;
    }
}