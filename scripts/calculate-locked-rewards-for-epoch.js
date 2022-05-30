const fetch = require('node-fetch');

const blockNumber = 27172278
const epoch = 1

const csvWriter = require('csv-writer').createObjectCsvWriter({
  path: `scripts/epoch-${epoch}-rewards.csv`,
  header: [
    { id: 'user', title: 'Wallet' },
    { id: 'amountFate', title: 'Fate_Rewards' },
  ]
});

const hardhat = require("hardhat");
const ethers = hardhat.ethers;

const multiplierForEpoch = ethers.BigNumber.from('115')
const divisorForEpoch = ethers.BigNumber.from('10')

const gqlBody = (skip) => {
  return `{"query":"{  userEpochTotalLockedRewardByPools(first: 1000, skip: ${skip}, orderBy: user, orderDirection: asc, block: {number: ${blockNumber}}, where: {epoch: ${epoch}}) {    user    poolId    amountFate  }}","variables":null,"operationName":null}`
}

async function main() {
  // Hardhat always runs the `compile` task when running scripts with its command
  // line interface.
  if (hardhat.network.config.chainId !== 1666600000) {
    throw new Error('Invalid chainId, found ' + hardhat.network.config.chainId);
  }

  const multicall = await ethers.getContractAt('Multicall', '0x41Fec4E5De930d8a618900973f0A678114C27361');
  const rewardController = await ethers.getContractAt('FateRewardControllerV2', '0x04170495EA41288225025De3CDFE9A9799121861');

  const userAndPoolIdAndAmountFateAtIndex = {}
  const pendingFateCalls = []
  for (let i = 0; i < 100; i++) {
    const result = await fetch('https://graph.t.hmny.io/subgraphs/name/fatex-dao/fatex-dao-rewards', {
      body: gqlBody(i * 1000),
      method: 'POST'
    }).then(response => response.json())
      .then(json => json.data.userEpochTotalLockedRewardByPools)

    if (result.length === 0) {
      break;
    }

    result.forEach((item, index) => {
      userAndPoolIdAndAmountFateAtIndex[(i * 1000) + index] = {
        user: item.user,
        poolId: item.poolId,
        amountFate: ethers.utils.parseUnits(item.amountFate, 18)
      }
      pendingFateCalls.push({
        target: rewardController.address,
        callData: rewardController.interface.encodeFunctionData('pendingFate', [item.poolId, item.user])
      })
    })
  }

  // Now batch the FateRewardController::pendingFate calls
  const chunkSize = 500;
  const numberOfChunks = Math.floor(pendingFateCalls.length / chunkSize) + 1
  let pendingFates = []
  for (let i = 0; i < numberOfChunks; i++) {
    const pendingFateResults = await multicall.callStatic.aggregate(
      pendingFateCalls.slice(i * chunkSize, (i * chunkSize) + chunkSize),
      { blockTag: blockNumber }
    )
    console.log('got pending fate for chunk ', i + 1)
    const pendingFatesAtIndex = pendingFateResults[1].map(rawPendingFate => {
      return ethers.BigNumber.from(rawPendingFate).mul(multiplierForEpoch).div(divisorForEpoch)
    })
    pendingFates = pendingFates.concat(pendingFatesAtIndex)
  }

  const totalLockedFatesByUser = {}
  pendingFates.forEach((pendingFate, index) => {
    const userStruct = userAndPoolIdAndAmountFateAtIndex[index]
    if (!totalLockedFatesByUser[userStruct.user]) {
      totalLockedFatesByUser[userStruct.user] = ethers.BigNumber.from('0');
    }
    totalLockedFatesByUser[userStruct.user] = totalLockedFatesByUser[userStruct.user].add(userStruct.amountFate).add(pendingFate);
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
