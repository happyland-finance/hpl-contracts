const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,
  sleepFor,
} = require('../js-helpers/deploy')
const { upgrades } = require('hardhat')
const _ = require('lodash')
const constants = require('../js-helpers/constants')
const PancakeFactoryABI = require('../abi/IPancakeFactory.json')
const PancakeRouterABI = require('../abi/IPancakeRouter02.json')

module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()
  const network = await hre.network
  const deployData = {}

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name)

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  log(' Masterchef deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  if (parseInt(chainId) == 31337) return

  let hplAddress = require(`../deployments/${chainId}/HPL.json`).address
  let hpwAddress = require(`../deployments/${chainId}/HPW.json`).address
  let devfundAddress = require(`../deployments/${chainId}/DevFund.json`).address
  let RewardDistributorAddress = require(`../deployments/${chainId}/RewardDistributor.json`)
    .address
  let TokenLockAddress = require(`../deployments/${chainId}/TokenLock.json`)
    .address
  let MasterChefAddress = require(`../deployments/${chainId}/MasterChef.json`)
    .address

  let startBlock = 0
  if (chainId == 56) {
    startBlock = 14212426 + 4 * 1200 + 100
  }
  log('Deploying MasterChef...')
  const MasterChef = await ethers.getContractFactory('MasterChef')
  await upgrades.upgradeProxy(
    MasterChefAddress,
    MasterChef,
    [
      ethers.utils.parseEther('0.5'),
      0,
      startBlock,
      RewardDistributorAddress,
      TokenLockAddress,
    ],
    { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
  )

  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['masterchefupgrade']
