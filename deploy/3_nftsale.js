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
  let wareHouseAddress = require(`../deployments/${chainId}/WareHouse.json`).address

  const Land = await ethers.getContractFactory('Land')
  const land = await Land.attach(landAddress)
  log('Land address : ', land.address)

  const WareHouse = await ethers.getContractFactory('WareHouse')
  const wareHouse = await WareHouse.attach(wareHouseAddress)
  log('WareHouse address : ', wareHouse.address)

  log('Deploying NFTSale...')
  const NFTSale = await ethers.getContractFactory('NFTSale')
  const NFTSaleInstance = await NFTSale.deploy()
  const nftSale = await NFTSaleInstance.deployed()
  log('NFTSale address : ', nftSale.address)
  deployData['NFTSale'] = {
    abi: getContractAbi('NFTSale'),
    address: nftSale.address,
    deployTransaction: nftSale.deployTransaction,
  }

  log('setFactory Land...')
  await land.setFactory(nftSale.address)
  log('setFactory WareHouse...')
  await wareHouse.setFactory(nftSale.address)

  log('Initializing NFTSale...')
  let landPrices = constants.getLandPrices(chainId)
  let rarities = landPrices.rarites
  let prices = landPrices.prices
  prices = prices.map(p => ethers.utils.parseEther(p))
  await nftSale.initialize(
    wareHouse.address,
    land.address,
    ethers.utils.parseEther(constants.getWareHousePrice(chainId)),
    rarities,
    prices,
    constants.getNFTSaleFeeTo(chainId)
  )

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['nftsale']
