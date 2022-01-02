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
  beforeEach(async () => {
    const HPL = await ethers.getContractFactory('HPL')
    const HPLInstance = await HPL.deploy()
    hpl = await HPLInstance.deployed()
    await hpl.initialize(
      owner.address,
      stakingRewardTreasury.address,
      ethers.constants.AddressZero,
    )

    const HPW = await ethers.getContractFactory('HPW')
    hpw = await upgrades.deployProxy(HPW, [ethers.constants.AddressZero], {
      unsafeAllow: ['delegatecall'],
      kind: 'uups',
    }) //unsafeAllowCustomTypes: true,

    //mocks
    const ERC20Mock = await ethers.getContractFactory('ERC20Mock')
    const ERC20MockInstance1 = await ERC20Mock.deploy()
    lp1 = await ERC20MockInstance1.deployed()
    const ERC20MockInstance2 = await ERC20Mock.deploy()
    lp2 = await ERC20MockInstance2.deployed()

    const RewardDistributor = await ethers.getContractFactory(
      'RewardDistributor',
    )
    rewardDistributor = await upgrades.deployProxy(
      RewardDistributor,
      [
        owner.address,
        hpl.address,
        hpw.address,
        0,
        0,
        ethers.constants.AddressZero,
      ],
      { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
    )

    const TokenLock = await ethers.getContractFactory('TokenLock')
    tokenLock = await upgrades.deployProxy(
      TokenLock,
      [ethers.constants.AddressZero],
      { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
    )

    const MasterChef = await ethers.getContractFactory('MasterChef')

    masterChef = await upgrades.deployProxy(
      MasterChef,
      [
        ethers.utils.parseEther('1.0'),
        ethers.utils.parseEther('1.0'),
        0,
        rewardDistributor.address,
        tokenLock.address,
      ],
      {
        unsafeAllow: ['delegatecall'],
        kind: 'uups',
      },
    ) //unsafeAllowCustomTypes: true,

    //set locker
    await tokenLock.setLockers([masterChef.address], true)
    await rewardDistributor.setLockers([masterChef.address], true)

    //set minter
    await hpw.setMinters([rewardDistributor.address], true)
    await hpl.transfer(
      rewardDistributor.address,
      ethers.utils.parseEther('1000000'),
    )

    await lp1.transfer(user1.address, ethers.utils.parseEther('50000'))
    await lp1.transfer(user2.address, ethers.utils.parseEther('50000'))

    await lp2.transfer(user3.address, ethers.utils.parseEther('50000'))
    await lp2.transfer(user4.address, ethers.utils.parseEther('50000'))

    await masterChef.add(1, lp1.address, 86400 * 7 * 2, true)
    await masterChef.add(1, lp2.address, 86400 * 7 * 2, true)
  })

  it('MasterChef', async function () {
    //cannot stake with lock less than 2 weeks
    await lp1
      .connect(user1)
      .approve(masterChef.address, ethers.utils.parseEther('1000000'))
    await lp1
      .connect(user2)
      .approve(masterChef.address, ethers.utils.parseEther('1000000'))
    await lp2
      .connect(user3)
      .approve(masterChef.address, ethers.utils.parseEther('1000000'))
    await lp2
      .connect(user4)
      .approve(masterChef.address, ethers.utils.parseEther('1000000'))
    await expect(
      masterChef
        .connect(user1)
        .deposit(0, ethers.utils.parseEther('1000'), 86400 * 7 * 2 - 1),
    ).to.be.revertedWith('minimum stake duration is 2 weeks')
    //stake ok
    await masterChef
      .connect(user1)
      .deposit(0, ethers.utils.parseEther('1000'), 86400 * 7 * 2)

    await masterChef
      .connect(user2)
      .deposit(0, ethers.utils.parseEther('1000'), 86400 * 7 * 4)

    await increaseBlock(100)

    //pending reward of user2 must be greter than user1
    let user1PendingReward = await masterChef.pendingRewards(0, user1.address)
    let user2PendingReward = await masterChef.pendingRewards(0, user2.address)

    expect(user2PendingReward._hpl).to.be.gt(user1PendingReward._hpl)

    //deposit more
    await masterChef
      .connect(user1)
      .deposit(0, ethers.utils.parseEther('1000'), 86400 * 7 * 3)

    await masterChef
      .connect(user2)
      .deposit(0, ethers.utils.parseEther('1000'), 86400 * 7 * 5)

    await masterChef
      .connect(user3)
      .deposit(1, ethers.utils.parseEther('1000'), 86400 * 7 * 3)

    await masterChef
      .connect(user4)
      .deposit(1, ethers.utils.parseEther('1000'), 86400 * 7 * 5)

    //cannot withdraw
    await expect(
      masterChef.connect(user1).withdraw(0, ethers.utils.parseEther('10'), 0),
    ).to.be.revertedWith('withdraw: not unlock time')

    await expect(
      masterChef.connect(user1).withdraw(0, ethers.utils.parseEther('10'), 0),
    ).to.be.revertedWith('withdraw: not unlock time')

    //advance 2 weeks
    await increaseTime(2 * 86400 * 7)

    await masterChef
      .connect(user1)
      .withdraw(0, ethers.utils.parseEther('500'), 0)

    await expect(
      masterChef.connect(user1).withdraw(0, ethers.utils.parseEther('600'), 0),
    ).to.be.revertedWith('withdraw: not good')

    let totalWeight = (await masterChef.poolInfo(0)).totalWeight
    console.log('totalWeight', totalWeight.toString())
    await masterChef
      .connect(user1)
      .withdraw(0, ethers.utils.parseEther('500'), 0)

    //deposit count must be 1
    let userInfo = await masterChef.getUserInfo(0, user1.address)
    expect(userInfo.deposits.length).to.be.eq(1)

    await increaseTime(2 * 86400 * 7)
    await masterChef
      .connect(user2)
      .withdraw(0, ethers.utils.parseEther('1000'), 0)

    let lp1PoolBalance = await lp1.balanceOf(masterChef.address)
    console.log(lp1PoolBalance.toString())

    totalWeight = (await masterChef.poolInfo(0)).totalWeight
    console.log('totalWeight', totalWeight.toString())

    await increaseTime(2 * 86400 * 7)
    await masterChef
      .connect(user1)
      .withdraw(0, ethers.utils.parseEther('1000'), 0)
    await masterChef
      .connect(user2)
      .withdraw(0, ethers.utils.parseEther('1000'), 0)

    await masterChef
      .connect(user3)
      .withdraw(1, ethers.utils.parseEther('1000'), 0)
    await masterChef
      .connect(user4)
      .withdraw(1, ethers.utils.parseEther('1000'), 0)

    lp1PoolBalance = await lp1.balanceOf(masterChef.address)
    console.log(lp1PoolBalance.toString())
    //total weight must be 0
    totalWeight = (await masterChef.poolInfo(0)).totalWeight
    console.log('totalWeight', totalWeight.toString())

    userInfo = await masterChef.getUserInfo(0, user1.address)
    console.log('stakeWeight', userInfo.stakeWeight.toString())

    expect(totalWeight).to.be.eq(0)
    expect(userInfo.stakeWeight).to.be.eq(0)
    expect(userInfo.stakeAmount).to.be.eq(0)
  })
})
