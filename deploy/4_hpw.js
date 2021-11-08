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
  log(' HPW token deployment');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log('  Using Network: ', chainNameById(chainId));
  log('  Using Accounts:');
  log('  - Deployer:          ', signers[0].address);
  log('  - network id:          ', chainId);
  log(' ');

  if (parseInt(chainId) == 31337) return
  const _stakingRewardTreasury = constants.getStakingRewardTreasury(chainId)
  const uniswapRouteAddress = constants.getRouter(chainId)

  log("Deploying LiquidityHoldingHPW...");
  const LiquidityHoldingHPW = await ethers.getContractFactory("LiquidityHoldingHPW")
  const liquidityHoldingHPWInstance = await LiquidityHoldingHPW.deploy()
  const liquidityHoldingHPW = await liquidityHoldingHPWInstance.deployed()
  log("LiquidityHoldingHPW address : ", liquidityHoldingHPW.address);

  const TransferFeeHPW = await ethers.getContractFactory("TransferFeeHPW")
  const transferFeeHPWInstance = await TransferFeeHPW.deploy()
  const transferFeeHPW = await transferFeeHPWInstance.deployed()
  await transferFeeHPW.setZeroFeeList([signers[0].address], true)
  log("TransactionFee address : ", transferFeeHPW.address);

  log('  Deploying HPW Token...');
  const HPW = await ethers.getContractFactory('HPW');
  const hpw = await upgrades.deployProxy(HPW, [liquidityHoldingHPW.address, transferFeeHPW.address], { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 })
  await liquidityHoldingHPW.initialize(hpw.address, uniswapRouteAddress)
  log('  - HPW:         ', hpw.address);

  //create liqidity pair
  let pairedToken = constants.getPairedToken(chainId)
  let router = await ethers.getContractAt(PancakeRouterABI, uniswapRouteAddress)
  let factoryAddress = await router.factory()
  let factory = await ethers.getContractAt(PancakeFactoryABI, factoryAddress)
  await factory.createPair(hpw.address, pairedToken)
  await sleepFor(5000)
  let pairAddress = await factory.getPair(hpw.address, pairedToken)
  log('Pair', pairAddress)
  await liquidityHoldingHPW.setLiquidityPair(pairAddress)

  deployData['HPW'] = {
    abi: getContractAbi('HPW'),
    address: hpw.address,
    deployTransaction: hpw.deployTransaction,
  }
  deployData['LiquidityHoldingHPW'] = {
    abi: getContractAbi('LiquidityHoldingHPW'),
    address: liquidityHoldingHPW.address,
    deployTransaction: liquidityHoldingHPW.deployTransaction,
  }
  deployData['TransferFeeHPW'] = {
    abi: getContractAbi('TransferFeeHPW'),
    address: transferFeeHPW.address,
    deployTransaction: transferFeeHPW.deployTransaction,
  }

  saveDeploymentData(chainId, deployData);
  log('\n  Contract Deployment Data saved to "deployments" directory.');

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
};

module.exports.tags = ['hpw']
