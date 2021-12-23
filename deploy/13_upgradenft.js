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
  log(' HPL NFTs deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  if (parseInt(chainId) == 31337) return
  let NFTSaleAddress = require(`../deployments/${chainId}/NFTSale.json`).address

  log('Deploying Land...')
  const UpgradeNFT = await ethers.getContractFactory('UpgradeNFT')
  const UpgradeNFTInstance = await UpgradeNFT.deploy()
  const upgradeNFT = await UpgradeNFTInstance.deployed()
  await upgradeNFT.setFactory(NFTSaleAddress)

  log('UpgradeNFT address : ', upgradeNFT.address)
  deployData['UpgradeNFT'] = {
    abi: getContractAbi('UpgradeNFT'),
    address: upgradeNFT.address,
    deployTransaction: upgradeNFT.deployTransaction,
  }

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['upgradenft']
