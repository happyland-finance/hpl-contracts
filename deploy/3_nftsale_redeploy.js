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

  let landAddress = require(`../deployments/${chainId}/Land.json`).address
  let houseAddress = require(`../deployments/${chainId}/House.json`).address

  const Land = await ethers.getContractFactory('Land')
  const land = await Land.attach(landAddress)
  log('Land address : ', land.address)

  const House = await ethers.getContractFactory('House')
  const house = await House.attach(houseAddress)
  log('House address : ', house.address)

  log('Initializing NFTSale parameters...')
  let landSettings = constants.getLandPrices(chainId)
  let landRarities = landSettings.rarites
  let landPrices = landSettings.prices

  let houseSettings = constants.getHousePrices(chainId)
  let houseRarities = houseSettings.rarites
  let housePrices = houseSettings.prices

  landPrices = landPrices.map(p => ethers.utils.parseEther(p))
  housePrices = housePrices.map(p => ethers.utils.parseEther(p))

  log('Deploying NFTSale...')
  const NFTSale = await ethers.getContractFactory('NFTSale')
  const nftSale = await upgrades.deployProxy(NFTSale, [house.address, land.address, houseRarities, housePrices, landRarities, landPrices, constants.getNFTSaleFeeTo(chainId), constants.getOperator(chainId)], { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 })
  log('NFTSale address : ', nftSale.address)
  deployData['NFTSale'] = {
    abi: getContractAbi('NFTSale'),
    address: nftSale.address,
    deployTransaction: nftSale.deployTransaction,
  }

  log('setFactory Land...')
  await land.setFactory(nftSale.address)
  log('setFactory WareHouse...')
  await house.setFactory(nftSale.address)

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['nftsale']
