const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,
} = require('../js-helpers/deploy')
const constants = require('../js-helpers/constants')
const { upgrades } = require('hardhat')
const _ = require('lodash')

module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()
  const network = await hre.network
  const deployData = {}

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name)
  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  log(' Upgrade Market deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  if (parseInt(chainId) == 31337) return

  let landAddress = require(`../deployments/${chainId}/Land.json`).address
  let hplAddress = require(`../deployments/${chainId}/HPL.json`).address
  let marketAddress = require(`../deployments/${chainId}/Market.json`).address

  const Land = await ethers.getContractFactory('Land')
  const land = await Land.attach(landAddress)

  const marketPaymentTokens = constants.getMarketPaymentTokens(chainId)
  marketPaymentTokens.push('0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF')
  marketPaymentTokens.push(hplAddress)

  log('Upgrade Market...')
  const Market = await ethers.getContractFactory('Market')
  await upgrades.upgradeProxy(
      marketAddress,
      Market,
      [land.address, marketPaymentTokens, constants.getNFTSaleFeeTo(chainId)],
      { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
  )

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['marketupgrade']
