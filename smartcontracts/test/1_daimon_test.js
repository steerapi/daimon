const Daimon = artifacts.require('Daimon');
const timeout = require('await-timeout');
const getWeb3 = require('@drizzle-utils/get-web3');
const getContractInstance = require('@drizzle-utils/get-contract-instance');

async function assertRejects(fn, regExp) {
  let f = () => {};
  try {
    await fn();
  } catch (e) {
    f = () => {
      throw e;
    };
  } finally {
    assert.throws(f, regExp);
  }
}

async function getInstance(name, address) {
  const getWeb3 = require('@drizzle-utils/get-web3');
  const createDrizzleUtils = require('@drizzle-utils/core');

  // initialize the tooling
  const web3drizzle = await getWeb3({ customProvider: web3.currentProvider });
  const drizzleUtils = await createDrizzleUtils({ web3: web3drizzle });
  // const accounts = await drizzleUtils.getAccounts();

  // `instance` is a web3 Contract instance of the deployed contract
  let instance;
  if (address) {
    instance = await drizzleUtils.getContractInstance({
      abi: artifacts.require(name).abi,
      address: address,
    });
  } else {
    instance = await drizzleUtils.getContractInstance({
      artifact: artifacts.require(name),
    });
  }
  return instance;
}

contract('Daimon', async (accounts) => {
  it('should get multiplier', async () => {
    let instance = await getInstance('Daimon');
    let multiplier = await instance.methods.multiplier().call();
    // console.log('multiplier', multiplier);
    // assert.equal(multiplier.toNumber(), 10 ** 18);
  });
  it('should get token address', async () => {
    let instance = await getInstance('Daimon');
    let address = await instance.methods.getTokenAddress().call();
    let tokenInstance = await getInstance('ProblemToken', address);
    let balance1 = await tokenInstance.methods.balanceOf(accounts[0]).call();
  });
  it('should calculate proper reward scaling', async () => {
    let instance = await Daimon.deployed();
    for (let i = 0; i < 100; i++) {
      let result = await instance.getRewardScaling.call(1000000000, i);
      assert.equal(result.toNumber(), Math.floor(1000000000 / 2 ** i));
    }
  });
  it('should get digest distances and scores', async () => {
    let instance = await Daimon.deployed();
    distances = [1001, 200, 300];
    scores = [1001, 200, 300];
    let result = await instance.getDigestDistancesScores.call(
      distances,
      scores
    );
    assert.equal(
      result,
      '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1'
    );
  });
  it('should return current time', async () => {
    let instance = await Daimon.deployed();
    let result = await instance.getCurrentTime();
    assert.equal(
      Math.abs(result.toNumber() - new Date().getTime() / 1000) < 900,
      true
    );
  });
  it('should get start time', async () => {
    let instance = await Daimon.deployed();
    let created = await instance.getCreatedTime();
    let result = await instance.getStartTime();
    assert.equal(result.toNumber() - created.toNumber(), 5);
  });
  it('should get next block time', async () => {
    let instance = await Daimon.deployed();
    let start = await instance.getStartTime();
    let result = await instance.getNextBlockTime();
    assert.equal(result.toNumber() - start.toNumber(), 5);
  });

  it('should reject submit model before start time', async () => {
    let instance = await getInstance('Daimon');
    let startTime = await instance.methods.getStartTime().call();
    let currentTime = await instance.methods.getCurrentTime().call();
    console.log('startTime', startTime.toNumber());
    console.log('currentTime', currentTime.toNumber(), startTime - currentTime);

    let result = instance.methods
      .submitModel(
        '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1'
      )
      .send({ from: accounts[0], gas: 6000000 });
    await new Promise((resolve, reject) => {
      result
        .on('error', (error) => {
          resolve();
        })
        .on('transactionHash', (transactionHash) => {
          reject('test set submission is allowed after period has ended');
        });
    });
  });

  it('should submit test set and reject after period has ended', async () => {
    let instance = await getInstance('Daimon');
    let result = instance.methods
      .submitTestSet(
        '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1'
      )
      .send({ from: accounts[0], gas: 6000000 });
    await result.promise;

    // wait for period to pass 5s
    await timeout.set(5000);
    result = instance.methods
      .submitTestSet(
        '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1'
      )
      .send({ from: accounts[0], gas: 6000000 });
    await new Promise((resolve, reject) => {
      result
        .on('error', (error) => {
          resolve();
        })
        .on('transactionHash', (transactionHash) => {
          reject('test set submission is allowed after period has ended');
        });
    });
  });

  it('should submit model and reject after the blocktime has passed', async () => {
    let instance = await getInstance('Daimon');
    let startTime = await instance.methods.getStartTime().call();
    let currentTime = await instance.methods.getCurrentTime().call();
    let nextBlockTime = await instance.methods.getNextBlockTime().call();
    console.log('startTime', startTime.toNumber());
    console.log('currentTime', currentTime.toNumber(), startTime - currentTime);
    console.log(
      'nextBlockTime',
      nextBlockTime.toNumber(),
      startTime - currentTime
    );
    let result = instance.methods
      .submitModel(
        '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1'
      )
      .send({ from: accounts[0], gas: 6000000 });
    await result.promise;
    await timeout.set(5000);
    result = instance.methods
      .submitModel(
        '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1'
      )
      .send({ from: accounts[0], gas: 6000000 });
    await new Promise((resolve, reject) => {
      result
        .on('error', (error) => {
          resolve();
        })
        .on('transactionHash', (transactionHash) => {
          reject('test set submission is allowed after period has ended');
        });
    });
  });

  it('should commit', async () => {
    let instance = await getInstance('Daimon');
    let result = instance.methods
      .commit()
      .send({ from: accounts[0], gas: 6000000 });
    await result.promise;

    // const BN = web3.utils.BN;
    // console.log(
    //   'typeof new BN(1000).toNumber()',
    //   typeof new BN(1000).toNumber()
    // );
  });

  it('should vote', async () => {
    let instance = await getInstance('Daimon');
    result = instance.methods
      .vote(
        '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1',
        ['1000'],
        ['1000']
      )
      .send({ from: accounts[0], gas: 6000000 });
    await result.promise;
    await timeout.set(5000);
  });

  it('should reward', async () => {
    let instance = await getInstance('Daimon');

    let address = await instance.methods.getTokenAddress().call();
    console.log('address', address);
    let tokenInstance = await getInstance('ProblemToken', address);
    let balance1 = await tokenInstance.methods.balanceOf(accounts[0]).call();
    console.log('balance1', balance1.toNumber());

    result = instance.methods
      .commit()
      .send({ from: accounts[0], gas: 6000000 });
    result.on('receipt', (receipt) => {
      console.log('receipt', receipt);
    });
    await result.promise;

    await timeout.set(5000);

    let balance2 = await tokenInstance.methods.balanceOf(accounts[0]).call();
    console.log('balance2', balance2.toNumber());
    assert.equal(balance2.toNumber(), 2000);
  });
});
