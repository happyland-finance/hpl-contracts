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
  log(' HPL token deployment');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log('  Using Network: ', chainNameById(chainId));
  log('  Using Accounts:');
  log('  - Deployer:          ', signers[0].address);
  log('  - network id:          ', chainId);
  log(' ');

  if (parseInt(chainId) == 31337) return
  const _stakingRewardTreasury = constants.getStakingRewardTreasury(chainId)
  const uniswapRouteAddress = constants.getRouter(chainId)
  let hplAddress = require(`../deployments/${chainId}/HPL.json`).address
  log('  Upgrading HPL Token...');
  const HPLUpgrade = await ethers.getContractFactory('HPLUpgrade');
  await upgrades.upgradeProxy(hplAddress, HPLUpgrade, [signers[0].address, _stakingRewardTreasury, signers[0].address], { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 })

  saveDeploymentData(chainId, deployData);
  log('\n  Contract Deployment Data saved to "deployments" directory.');

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
};

module.exports.tags = ['hplupgrade']
