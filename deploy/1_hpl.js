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

  log("Deploying HPLHook...");
  const HPLHook = await ethers.getContractFactory("HPLHook")
  const hplhook = await upgrades.deployProxy(HPLHook, [uniswapRouteAddress], { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 })
  log("HPLHook address : ", hplhook.address);

  await hplhook.setZeroFeeList([signers[0].address], true)

  log('  Deploying HPL Token...');
  const HPL = await ethers.getContractFactory('HPL');
  const hpl = await upgrades.deployProxy(HPL, [signers[0].address, _stakingRewardTreasury, hplhook.address], { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 4000000 })
  log('  - HPL:         ', hpl.address);

  await hplhook.setHPL(hpl.address)

  //create liqidity pair
  let pairedToken = constants.getPairedToken(chainId)
  let router = await ethers.getContractAt(PancakeRouterABI, uniswapRouteAddress)
  let factoryAddress = await router.factory()
  let factory = await ethers.getContractAt(PancakeFactoryABI, factoryAddress)
  await factory.createPair(hpl.address, pairedToken)
  await sleepFor(15000)
  let pairAddress = await factory.getPair(hpl.address, pairedToken)
  log('Pair', pairAddress)
  await hplhook.setLiquidityPair(pairAddress)
  await hpl.setPancakePairs([pairAddress], true)

  deployData['HPL'] = {
    abi: getContractAbi('HPL'),
    address: hpl.address,
    deployTransaction: hpl.deployTransaction,
  }

  deployData['HPLHook'] = {
    abi: getContractAbi('HPLHook'),
    address: hplhook.address,
    deployTransaction: hplhook.deployTransaction,
  }

  saveDeploymentData(chainId, deployData);
  log('\n  Contract Deployment Data saved to "deployments" directory.');

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
};

module.exports.tags = ['hpl']
