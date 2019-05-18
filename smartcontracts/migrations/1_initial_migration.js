const Migrations = artifacts.require('Migrations');
const Daimon = artifacts.require('Daimon');
const DaimonFactory = artifacts.require('DaimonFactory');
const ProblemToken = artifacts.require('ProblemToken');

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  //   string memory name,
  //   string memory symbol,
  //   uint8 decimals,
  //   uint256 startTime_,
  //   uint256 blockTime_
  deployer.deploy(DaimonFactory);
  deployer.deploy(ProblemToken, 'Daimon', 'DAIMON', 18);
  deployer.deploy(Daimon, 'Daimon', 'DAIMON', 18, 5, 5);
};
