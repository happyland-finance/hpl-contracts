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

  log("Deploying RewardDistributor...");
  const RewardDistributor = await ethers.getContractFactory("RewardDistributor")
  const rewardDistributor = await upgrades.deployProxy(RewardDistributor, [constants.getDevRewardAddress(chainId), hplAddress, hpwAddress, 0, 0, ethers.constants.AddressZero], { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 })
  log("RewardDistributor address : ", rewardDistributor.address);
  deployData['RewardDistributor'] = {
    abi: getContractAbi('RewardDistributor'),
    address: rewardDistributor.address,
    deployTransaction: rewardDistributor.deployTransaction,
  }

  log("Deploying TokenLock...");
  const TokenLock = await ethers.getContractFactory("TokenLock")
  const tokenLock = await upgrades.deployProxy(TokenLock, [ethers.constants.AddressZero], { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 })
  log("TokenLock address : ", tokenLock.address);
  deployData['TokenLock'] = {
    abi: getContractAbi('TokenLock'),
    address: tokenLock.address,
    deployTransaction: tokenLock.deployTransaction,
  }

  log("Deploying MasterChef...");
  const MasterChef = await ethers.getContractFactory("MasterChef")
  const masterchef = await upgrades.deployProxy(MasterChef, [hplAddress, hpwAddress, ethers.utils.parseEther('0.9'), ethers.utils.parseEther('2'), 0, rewardDistributor.address, tokenLock.address], { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 })
  log("MasterChef address : ", masterchef.address);
  deployData['MasterChef'] = {
    abi: getContractAbi('MasterChef'),
    address: masterchef.address,
    deployTransaction: masterchef.deployTransaction,
  }

  log("Initializing RewardDistributor...")
  await rewardDistributor.setLockers([masterchef.address], true)

  log("Initializing TokenLock...")
  await tokenLock.setLockers([masterchef.address], true)

  log("Adding HPW Minter...")
  const HPW = await ethers.getContractFactory("HPW")
  let hpwContract = await HPW.attach(hpwAddress)
  await hpwContract.setMinters([rewardDistributor.address], true)

  log("Set whitelist...")
  const HPL = await ethers.getContractFactory("HPL")
  let hplContract = await HPL.attach(hplAddress)
  let hplHookAddress = hplContract.tokenHook()
  let hpwHookAddress = hpwContract.tokenHook()

  let HPLHook = await ethers.getContractFactory("HPLHook")
  let hplHookContract = await HPLHook.attach(hplHookAddress)
  log("Set whitelist for HPL...")
  await hplHookContract.setZeroFeeList([masterchef.address, rewardDistributor.address, tokenLock.address], true)

  let HPWHook = await ethers.getContractFactory("HPWHook")
  let hpwHookContract = await HPWHook.attach(hpwHookAddress)
  log("Set whitelist for HPW...")
  await hpwHookContract.setZeroFeeList([masterchef.address, rewardDistributor.address, tokenLock.address], true)

  saveDeploymentData(chainId, deployData);
  log('\n  Contract Deployment Data saved to "deployments" directory.');

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
};

module.exports.tags = ['masterchef']
