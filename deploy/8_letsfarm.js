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

module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()
  const network = await hre.network
  const deployData = {}

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name)

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  log(' LetsFarm deployment')
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

  log('Deploying HappyLand...')
  const LetsFarm = await ethers.getContractFactory('LetsFarm')
  const letsfarm = await upgrades.deployProxy(
    LetsFarm,
    [hplAddress, hpwAddress, constants.getOperator(chainId)],
    { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
  )
  log('LetsFarm address : ', letsfarm.address)
  deployData['LetsFarm'] = {
    abi: getContractAbi('LetsFarm'),
    address: letsfarm.address,
    deployTransaction: letsfarm.deployTransaction,
  }

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['letsfarm']
