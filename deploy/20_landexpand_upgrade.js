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
  log(' Upgrade LandExpand deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  if (parseInt(chainId) == 31337) return

  let hplAddress = require(`../deployments/${chainId}/HPL.json`).address
  let hpwAddress = require(`../deployments/${chainId}/HPW.json`).address
  let landAddress = require(`../deployments/${chainId}/Land.json`).address
  let landSaleAddress = require(`../deployments/${chainId}/LandSale.json`).address
  let landExpandAddress = require(`../deployments/${chainId}/LandExpand.json`).address

  let hplExpandFee = ethers.utils.parseEther('80')
  let hpwExpandFee = ethers.utils.parseEther('400')

  log('Deploying LandExpand...')
  const LandExpand = await ethers.getContractFactory('LandExpand')
  await upgrades.upgradeProxy(
      landExpandAddress,
      LandExpand,
      [
        hplAddress, hpwAddress, landAddress, hplExpandFee, hpwExpandFee, landSaleAddress, constants.getOperator(chainId)
      ],
      { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
  )

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['landexpandupgrade']
