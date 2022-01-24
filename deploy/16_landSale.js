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
  log(' HPL LandSale deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  if (parseInt(chainId) == 31337) return

  let landAddress = require(`../deployments/${chainId}/Land.json`).address

  log('Deploying LandSale...')
  const LandSale = await ethers.getContractFactory('LandSale')
  const landSale = await upgrades.deployProxy(
      LandSale,
    [
      landAddress,
    ],
    { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
  )
  log('LandSale address : ', landSale.address)
  deployData['LandSale'] = {
    abi: getContractAbi('LandSale'),
    address: landSale.address,
    deployTransaction: landSale.deployTransaction,
  }

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['landsale']
