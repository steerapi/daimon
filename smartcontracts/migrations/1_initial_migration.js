const Migrations = artifacts.require('Migrations');
const Daimon = artifacts.require('Daimon');

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  //   string memory name,
  //   string memory symbol,
  //   uint8 decimals,
  //   uint256 startTime_,
  //   uint256 blockTime_
  deployer.deploy(Daimon, 'Daimon', 'DAIMON', 18, 5, 5);
};
