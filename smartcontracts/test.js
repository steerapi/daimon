const Web3 = require('web3');
const getWeb3 = require('@drizzle-utils/get-web3');
const getContractInstance = require('@drizzle-utils/get-contract-instance');
const createDrizzleUtils = require('@drizzle-utils/core');
const timeout = require('await-timeout');

const fs = require('fs');
const web3 = new Web3('http://127.0.0.1:7545');

async function getAccounts(name, address) {
  const web3drizzle = await getWeb3({ customProvider: web3.currentProvider });
  const drizzleUtils = await createDrizzleUtils({ web3: web3drizzle });
  const accounts = await drizzleUtils.getAccounts();
  return accounts;
}
async function getInstance(name, address) {
  // initialize the tooling
  const web3drizzle = await getWeb3({ customProvider: web3.currentProvider });
  const drizzleUtils = await createDrizzleUtils({ web3: web3drizzle });
  // const accounts = await drizzleUtils.getAccounts();
  // console.log(accounts);

  // `instance` is a web3 Contract instance of the deployed contract
  // console.log(
  //   'JSON.parse(fs.readFileSync(name))',
  //   JSON.parse(fs.readFileSync(name)).abi
  // );
  let instance;
  if (address) {
    instance = await drizzleUtils.getContractInstance({
      abi: JSON.parse(fs.readFileSync(name)).abi,
      address: address,
    });
  } else {
    instance = await drizzleUtils.getContractInstance({
      artifact: JSON.parse(fs.readFileSync(name)),
    });
  }
  return instance;
}

async function run() {
  let accounts = await getAccounts();
  let instance = await getInstance(
    './build/contracts/Daimon.json',
    '0x0ee26436cD3915740ee48E6e95F27a3fe79CeD00'
  );

  let result = instance
    .deploy({
      data: JSON.parse(fs.readFileSync('./build/contracts/Daimon.json'))
        .bytecode,
      arguments: ['Daimon', 'DAIMON', 18, 5, 5],
    })
    .send({
      from: accounts[0],
      gas: 6000000,
    });
  result.on('receipt', async (receipt) => {
    // console.log(receipt.contractAddress);
    let instance = await getInstance(
      './build/contracts/Daimon.json',
      receipt.contractAddress
    );
    // let startTime = await instance.methods.getStartTime().call();
    // console.log('startTime', startTime);

    result = instance.methods
      .submitTestSet(
        '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1'
      )
      .send({ from: accounts[0], gas: 6000000 });
    await result.promise;

    // wait for period to pass 5s
    await timeout.set(5000);
    result = instance.methods
      .submitModel(
        '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1'
      )
      .send({ from: accounts[0], gas: 6000000 });
    await result.promise;
    result = instance.methods
      .vote(
        '0x48d1144d186da79f40e83bb8ac40d4060b0f329b17069a3162e2f5fc450783f1',
        ['100000000000000000'], // 100000000000000000
        ['100000000000000000'] // 100000000000000000
      )
      .send({ from: accounts[0], gas: 6000000 });
    await result.promise;
    await timeout.set(5000);

    result = await instance.methods.getCurrentScoreAt(0).call();
    console.log('getCurrentScoreAt 0 Before Commit', result.toString());

    result = await instance.methods.getCurrentDistanceAt(0).call();
    console.log('getCurrentDistanceAt 0 Before Commit', result.toString());

    result = instance.methods
      .commit()
      .send({ from: accounts[0], gas: 6000000 });
    await result.promise;
    await timeout.set(3000);

    result = await instance.methods.getCurrentScoreAt(0).call();
    console.log('getCurrentScoreAt 0 After Commit', result.toString());

    result = await instance.methods.getCurrentDistanceAt(0).call();
    console.log('getCurrentDistanceAt 0 After Commit', result.toString());

    // result = instance.methods.commit().send({ from: accounts[0], gas: 6000000 });
    // await result.promise;

    // await timeout.set(5000);
  });
}

run();
