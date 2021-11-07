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

  log('Deploying Land...')
  const Land = await ethers.getContractFactory('Land')
  const LandInstance = await Land.deploy()
  const land = await LandInstance.deployed()
  log('Land address : ', land.address)
  deployData['Land'] = {
    abi: getContractAbi('Land'),
    address: land.address,
    deployTransaction: land.deployTransaction,
  }

  log('Deploying WareHouse...')
  const WareHouse = await ethers.getContractFactory('WareHouse')
  const WareHouseInstance = await WareHouse.deploy()
  const wareHouse = await WareHouseInstance.deployed()
  log('WareHouse address : ', wareHouse.address)
  deployData['WareHouse'] = {
    abi: getContractAbi('WareHouse'),
    address: wareHouse.address,
    deployTransaction: wareHouse.deployTransaction,
  }

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

  log('Initializing Land...')
  await land.initialize(nftSale.address)
  log('Initializing WareHouse...')
  await wareHouse.initialize(nftSale.address)

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

module.exports.tags = ['nft']
