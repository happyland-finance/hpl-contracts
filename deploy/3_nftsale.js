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
  log(' HPL NFTSale deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  if (parseInt(chainId) == 31337) return

  let landAddress = require(`../deployments/${chainId}/Land.json`).address

  const Land = await ethers.getContractFactory('Land')
  const land = await Land.attach(landAddress)
  log('Land address : ', land.address)

  log('Deploying NFTSale...')
  const NFTSale = await ethers.getContractFactory('NFTSale')
  const nftSale = await upgrades.deployProxy(
    NFTSale,
    [
      land.address,
      constants.getNFTSaleFeeTo(chainId),
      constants.getOperator(chainId),
    ],
    { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
  )
  log('NFTSale address : ', nftSale.address)
  deployData['NFTSale'] = {
    abi: getContractAbi('NFTSale'),
    address: nftSale.address,
    deployTransaction: nftSale.deployTransaction,
  }

  log('setFactory Land...')
  await land.setFactory(nftSale.address)

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['nftsale']
