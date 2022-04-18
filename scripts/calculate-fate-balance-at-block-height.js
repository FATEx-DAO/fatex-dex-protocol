const fetch = require('node-fetch');
const fs = require('fs');
const csv = require('csv-parser');

const blockNumber = 25198540
const epoch = 1

const csvWriter = require('csv-writer').createObjectCsvWriter({
  path: `scripts/fate-balances-${blockNumber}.csv`,
  header: [
    { id: 'user', title: 'Wallet' },
    { id: 'amountFate', title: 'Fate_Rewards' },
  ]
});

const hardhat = require('hardhat');
const ethers = hardhat.ethers;

const allUsersGqlBody = (skip) => {
  return `{"query":"{  userEpochTotalLockedRewards(first: 1000, skip: ${skip}, orderBy: user, orderDirection: asc, block: {number: ${blockNumber}}) {    user    amountFate  }}","variables":null,"operationName":null}`
}

const userAndPoolGqlBody = (skip) => {
  return `{"query":"{  userEpochTotalLockedRewardByPools(first: 1000, skip: ${skip}, orderBy: user, orderDirection: asc, block: {number: ${blockNumber}}, where: {epoch: ${epoch}}) {    user    poolId    amountFate  }}","variables":null,"operationName":null}`
}


async function readCsv(filename) {
  const values = {}
  return new Promise((resolve) => {
    fs.createReadStream(filename)
      .pipe(csv())
      .on('data', function (row) {
        values[row.Wallet] = ethers.utils.parseUnits(row.Fate_Rewards, 18);
      })
      .on('end', function () {
        resolve(values);
      })
  })
}

async function main() {
  // Hardhat always runs the 'compile' task when running scripts with its command
  // line interface.
  if (hardhat.network.config.chainId !== 1666600000) {
    throw new Error('Invalid chainId, found ' + hardhat.network.config.chainId);
  }

  const epoch0Map = await readCsv('./scripts/epoch-0-rewards.csv');
  const epoch1Map = await readCsv('./scripts/epoch-1-rewards_(AS_OF_2022-03-02_05:49:49_UTC).csv');

  const multicall = await ethers.getContractAt('Multicall', '0x41Fec4E5De930d8a618900973f0A678114C27361');
  const fateGovToken = await ethers.getContractAt('VotingPowerToken', '0x72d2f2d57cc5d3e78c456616e1d17e73e8848c3a');
  const rewardController = await ethers.getContractAt('FateRewardControllerV2', '0x04170495EA41288225025De3CDFE9A9799121861');

  const pendingFateCalls = []
  for (let i = 0; i < 100; i++) {
    const result = await fetch('https://graph.t.hmny.io/subgraphs/name/fatex-dao/fatex-dao-rewards', {
      body: userAndPoolGqlBody(i * 1000),
      method: 'POST'
    }).then(response => response.json())
      .then(json => json.data.userEpochTotalLockedRewardByPools)

    if (result.length === 0) {
      break;
    }

    result.forEach((item) => {
      pendingFateCalls.push({
        target: rewardController.address,
        callData: rewardController.interface.encodeFunctionData('pendingFate', [item.poolId, item.user]),
        user: item.user,
        poolId: item.poolId,
      })
    })
  }

  // Now batch the FateRewardController::pendingFate calls
  let chunkSize = 250;
  let numberOfChunks = Math.floor(pendingFateCalls.length / chunkSize) + 1
  let pendingFates = []
  for (let i = 0; i < numberOfChunks; i++) {
    const pendingFateResults = await multicall.callStatic.aggregate(
      pendingFateCalls.slice(i * chunkSize, (i * chunkSize) + chunkSize),
      { blockTag: blockNumber }
    )
    console.log('Got pending fate for chunk ', i + 1)
    const fatesForChunk = pendingFateResults[1].map(rawPendingFate => ethers.BigNumber.from(rawPendingFate))
    pendingFates = pendingFates.concat(fatesForChunk)
  }

  const userBalanceCalls = []
  const seenUsers = {}
  for (let i = 0; i < 100; i++) {
    const result = await fetch('https://graph.t.hmny.io/subgraphs/name/fatex-dao/fatex-dao-rewards', {
      body: allUsersGqlBody(i * 1000),
      method: 'POST'
    }).then(response => response.json())
      .then(json => json.data.userEpochTotalLockedRewards)

    if (result.length === 0) {
      break;
    }

    result.forEach((item) => {
      if (!seenUsers[item.user]) {
        seenUsers[item.user] = item.user;
        userBalanceCalls.push({
          target: fateGovToken.address,
          callData: fateGovToken.interface.encodeFunctionData('balanceOf', [item.user]),
          user: item.user
        });
      }
    })
  }

  // Now batch the FateRewardController::pendingFate calls
  chunkSize = 75;
  numberOfChunks = Math.floor(userBalanceCalls.length / chunkSize) + 1
  let userBalances = []
  for (let i = 0; i < numberOfChunks; i++) {
    const userBalanceResults = await multicall.callStatic.aggregate(
      userBalanceCalls.slice(i * chunkSize, (i * chunkSize) + chunkSize),
      { blockTag: blockNumber }
    )
    console.log('Got user balances for chunk ', i + 1)
    const userBalancesChunk = userBalanceResults[1].map(rawUserBalance => {
      return ethers.BigNumber.from(rawUserBalance)
    })
    userBalances = userBalances.concat(userBalancesChunk)
  }

  const totalLockedFatesByUser = {};

  pendingFates.forEach((pendingFate, index) => {
    const user = pendingFateCalls[index].user;
    if (!totalLockedFatesByUser[user]) {
      totalLockedFatesByUser[user] = ethers.BigNumber.from('0');
    }
    totalLockedFatesByUser[user] = totalLockedFatesByUser[user].add(pendingFate);
  })

  userBalances.forEach((userBalance, index) => {
    const user = userBalanceCalls[index].user;
    if (!totalLockedFatesByUser[user]) {
      totalLockedFatesByUser[user] = ethers.BigNumber.from('0');
    }
    totalLockedFatesByUser[user] = totalLockedFatesByUser[user].add(userBalance);
  })

  const result = Object.keys(totalLockedFatesByUser).map(key => {
    const ZERO = ethers.BigNumber.from('0');
    let epoch0Amount = epoch0Map[key] || ZERO;
    if (epoch0Amount.gt(ZERO)) {
      let week1 = epoch0Amount.div('18');
      let otherWeeks = epoch0Amount.div('36').mul('10');
      epoch0Amount = epoch0Amount.sub(week1).sub(otherWeeks);
    }
    const total = totalLockedFatesByUser[key].add(epoch0Amount).add(epoch1Map[key] || ZERO);
    return {
      user: key,
      amountFate: ethers.utils.formatEther(total),
    }
  })

  return csvWriter.writeRecords(result);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
