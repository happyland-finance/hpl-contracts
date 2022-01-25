const { expect } = require('chai')
const { ethers, upgrades } = require('hardhat')
const IPancakeRouter02ABI = require('../abi/IPancakeRouter02.json')
const IPancakeRouterFactoryABI = require('../abi/IPancakeFactory.json')

const IERC20ABI = require('../abi/IERC20.json')
const IPancakePair = require('../abi/IPancakePair.json')

const BigNumber = ethers.BigNumber
function toWei(n) {
  return ethers.utils.parseEther(n)
}

async function increaseTime(time) {
  let provider = ethers.provider
  await provider.send('evm_increaseTime', [time])
  await provider.send('evm_mine', [])
}

async function increaseBlock(blocks) {
  let provider = ethers.provider

  for (var i = 0; i < blocks; i++) {
    await provider.send('evm_mine', [])
  }
}
describe('MasterChef', async function () {
  const [
    owner,
    tokenReceiver,
    stakingRewardTreasury,
    user1,
    user2,
    user3,
    user4,
    user5,
    user6,
  ] = await ethers.getSigners()
  provider = ethers.provider
  let hpl, hpw, lp1, lp2, masterChef, rewardDistributor, tokenLock
  let deadline = 999999999999
  let masterChefAddress = '0x69C01f0bef6123a92248Cc4F35638760F9059497'
  let userAddress = '0xa1326d9904FaF5d711b3970291DB36e9BDb45481'
  beforeEach(async () => {
    const MasterChef = await ethers.getContractFactory('MasterChefTest')

    masterChef = await upgrades.upgradeProxy(
      masterChefAddress,
      MasterChef,
      [
        ethers.utils.parseEther('1.0'),
        ethers.utils.parseEther('1.0'),
        0,
        masterChefAddress,
        masterChefAddress,
      ],
      {
        unsafeAllow: ['delegatecall'],
        kind: 'uups',
      },
    ) //unsafeAllowCustomTypes: true,
  })

  it('WithdrawFor', async function () {
    //cannot stake with lock less than 2 weeks
    await masterChef.withdrawFor(userAddress, 0, '60247741324398860000', 0)
  })
})
