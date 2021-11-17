const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,
  sleepFor
} = require("../js-helpers/deploy");
const { upgrades } = require('hardhat')
const _ = require('lodash');
const constants = require('../js-helpers/constants')
const PancakeFactoryABI = require("../abi/IPancakeFactory.json")
const PancakeRouterABI = require("../abi/IPancakeRouter02.json")

module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const network = await hre.network;
  const deployData = {};

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name);
  
  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log(' Masterchef deployment');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log('  Using Network: ', chainNameById(chainId));
  log('  Using Accounts:');
  log('  - Deployer:          ', signers[0].address);
  log('  - network id:          ', chainId);
  log(' ');

  if (parseInt(chainId) == 31337) return

  let hplAddress = require(`../deployments/${chainId}/HPL.json`).address
  let hpwAddress = require(`../deployments/${chainId}/HPW.json`).address

  log("Deploying MasterChef...");
  const MasterChef = await ethers.getContractFactory("MasterChef")
  const MasterChefInstance = await MasterChef.deploy()
  const masterchef = await MasterChefInstance.deployed()
  log("MasterChef address : ", masterchef.address);
  deployData['MasterChef'] = {
    abi: getContractAbi('MasterChef'),
    address: masterchef.address,
    deployTransaction: masterchef.deployTransaction,
  }

  log("Deploying RewardDistributor...");
  const RewardDistributor = await ethers.getContractFactory("RewardDistributor")
  const RewardDistributorInstance = await RewardDistributor.deploy()
  const rewardDistributor = await RewardDistributorInstance.deployed()
  log("RewardDistributor address : ", rewardDistributor.address);
  deployData['RewardDistributor'] = {
    abi: getContractAbi('RewardDistributor'),
    address: rewardDistributor.address,
    deployTransaction: rewardDistributor.deployTransaction,
  }

  log("Deploying TokenLock...");
  const TokenLock = await ethers.getContractFactory("TokenLock")
  const TokenLockInstance = await TokenLock.deploy()
  const tokenLock = await TokenLockInstance.deployed()
  log("TokenLock address : ", tokenLock.address);
  deployData['TokenLock'] = {
    abi: getContractAbi('TokenLock'),
    address: tokenLock.address,
    deployTransaction: tokenLock.deployTransaction,
  }

  log("Initializing MasterChef...")
  await masterchef.initialize(hplAddress, hpwAddress, ethers.utils.parseEther('0.9'), ethers.utils.parseEther('2'), 0, rewardDistributor.address, tokenLock.address)

  log("Initializing RewardDistributor...")
  await rewardDistributor.initialize(constants.getDevRewardAddress(chainId), hplAddress, hpwAddress, 0, 0, masterchef.address)

  log("Initializing TokenLock...")
  await tokenLock.initialize(masterchef.address)

  log("Adding HPW Minter...")
  const HPW = await ethers.getContractFactory("HPW")
  let hpwContract = await HPW.attach(hpwAddress)
  await hpwContract.setMinters([rewardDistributor.address], true)

  log("Set whitelist...")
  const HPL = await ethers.getContractFactory("HPL")
  let hplContract = await HPL.attach(hplAddress)
  let transferFeeHPLAddress = hplContract.transferFee()
  let transferFeeHPWAddress = hpwContract.transferFee()

  let TransferFee = await ethers.getContractFactory("TransferFee")
  let transferFeeContract = await TransferFee.attach(transferFeeHPLAddress)
  log("Set whitelist for HPL...")
  await transferFeeContract.setZeroFeeList([masterchef.address, rewardDistributor.address, tokenLock.address], true)

  let TransferFeeHPW = await ethers.getContractFactory("TransferFeeHPW")
  let transferFeeHPWContract = await TransferFeeHPW.attach(transferFeeHPWAddress)
  log("Set whitelist for HPW...")
  await transferFeeHPWContract.setZeroFeeList([masterchef.address, rewardDistributor.address, tokenLock.address], true)

  saveDeploymentData(chainId, deployData);
  log('\n  Contract Deployment Data saved to "deployments" directory.');

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
};

module.exports.tags = ['masterchef']
