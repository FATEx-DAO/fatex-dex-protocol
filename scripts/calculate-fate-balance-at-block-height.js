const fetch = require('node-fetch');
const fs = require('fs');
const csv = require('csv-parser');

const blockNumber = 23579227

const csvWriter = require('csv-writer').createObjectCsvWriter({
  path: `scripts/fate-balances-${blockNumber}.csv`,
  header: [
    { id: 'user', title: 'Wallet' },
    { id: 'amountFate', title: 'Fate_Rewards' },
  ]
});

const hardhat = require('hardhat');
const { BigNumber } = require('ethers');
const ethers = hardhat.ethers;

const gqlBody = (skip) => {
  return `{"query":"{  userEpochTotalLockedRewards(first: 1000, skip: ${skip}, orderBy: user, orderDirection: asc, block: {number: ${blockNumber}}) {    user    amountFate  }}","variables":null,"operationName":null}`
}

async function readCsv(filename) {
  const values = []
  new Promise((resolve) => {
    fs.createReadStream(filename)
      .pipe(csv())
      .on('data', function (row) {
        console.log('row', row);
        values.push(row);
      })
      .on('end', function () {
        resolve(values);
      })
  })
}

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  if (hardhat.network.config.chainId !== 1666600000) {
    throw new Error('Invalid chainId, found ' + hardhat.network.config.chainId);
  }

  const multicall = await ethers.getContractAt('Multicall', '0x41Fec4E5De930d8a618900973f0A678114C27361');
  const fateGovToken = await ethers.getContractAt('VotingPowerToken', '0x72d2f2d57cc5d3e78c456616e1d17e73e8848c3a');

  const userAndEpochAndAmountFateAtIndex = {}
  const userBalanceCalls = []
  for (let i = 0; i < 100; i++) {
    const result = await fetch('https://graph.t.hmny.io/subgraphs/name/fatex-dao/fatex-dao-rewards', {
      body: gqlBody(i * 1000),
      method: 'POST'
    }).then(response => response.json())
      .then(json => json.data.userEpochTotalLockedRewards)

    if (result.length === 0) {
      break;
    }

    result.forEach((item) => {
      if (!userAndEpochAndAmountFateAtIndex[item.user]) {
        userAndEpochAndAmountFateAtIndex[item.user] = {
          user: item.user,
          amountFate: BigNumber.from('0'),
        }
      }

      const currentAmountFate = userAndEpochAndAmountFateAtIndex[item.user].amountFate
      userAndEpochAndAmountFateAtIndex[item.user] = {
        user: item.user,
        amountFate: currentAmountFate.add(ethers.utils.parseUnits(item.amountFate, 18))
      }
      userBalanceCalls.push({
        target: fateGovToken.address,
        callData: fateGovToken.interface.encodeFunctionData('balanceOf', [item.user]),
        user: item.user
      })
    })
  }

  // Now batch the FateRewardController::pendingFate calls
  const chunkSize = 100;
  const numberOfChunks = Math.floor(userBalanceCalls.length / chunkSize) + 1
  let userBalances = []
  for (let i = 0; i < numberOfChunks; i++) {
    const userBalanceResults = await multicall.callStatic.aggregate(
      userBalanceCalls.slice(i * chunkSize, (i * chunkSize) + chunkSize),
      { blockTag: blockNumber }
    )
    console.log('Got user balances for chunk ', i + 1)
    const userBalancesAtIndex = userBalanceResults[1].map(rawUserBalance => {
      return ethers.BigNumber.from(rawUserBalance)
    })
    userBalances = userBalances.concat(userBalancesAtIndex)
  }

  const totalLockedFatesByUser = {}
  userBalances.forEach((userBalance, index) => {
    const userStruct = userAndEpochAndAmountFateAtIndex[userBalanceCalls[index].user]
    if (!totalLockedFatesByUser[userStruct.user]) {
      totalLockedFatesByUser[userStruct.user] = ethers.BigNumber.from('0');
    }
    totalLockedFatesByUser[userStruct.user] = totalLockedFatesByUser[userStruct.user].add(userStruct.amountFate).add(userBalance);
  })

  const result = Object.keys(totalLockedFatesByUser).map(key => {
    return {
      user: key,
      amountFate: ethers.utils.formatEther(totalLockedFatesByUser[key]),
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
