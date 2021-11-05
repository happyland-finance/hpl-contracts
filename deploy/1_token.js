const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,

} = require("../js-helpers/deploy");
const { upgrades } = require('hardhat')
const _ = require('lodash');

module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const network = await hre.network;
  const deployData = {};

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name);
  const _stakingRewardTreasury = "0xf4e1e3cD1227dFe8B03d4fF3FBC422d483b31bf7"
  const uniswapRouteAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log(' HPL token deployment');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log('  Using Network: ', chainNameById(chainId));
  log('  Using Accounts:');
  log('  - Deployer:          ', signers[0].address);
  log('  - network id:          ', chainId);
  log(' ');

  if (parseInt(chainId) == 31337) return
  log("Deploying LiquidityHolding...");
  const LiquidityHolding = await ethers.getContractFactory("LiquidityHolding")
  const liquidityHoldingInstance = await LiquidityHolding.deploy()
  const liquidityHolding = await liquidityHoldingInstance.deployed()
  log("LiquidityHolding address : ", liquidityHolding.address);
  const TransferFee = await ethers.getContractFactory("TransferFee")
  const transferFeeInstance = await TransferFee.deploy()
  const transferFee = await transferFeeInstance.deployed()
  await transferFee.setZeroFeeList([signers[0].address], true)
  log("TransactionFee address : ", transferFee.address);
  log('  Deploying HPL Token...');
  const HPL = await ethers.getContractFactory('HPL');
  const hpl = await upgrades.deployProxy(HPL, [signers[0].address, _stakingRewardTreasury, liquidityHolding.address, transferFee.address], { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 })
  await liquidityHolding.initialize(hpl.address, uniswapRouteAddress)
  log('  - HPL:         ', hpl.address);
  deployData['HPL'] = {
    abi: getContractAbi('HPL'),
    address: hpl.address,
    deployTransaction: hpl.deployTransaction,
  }
  deployData['LiquidityHolding'] = {
    abi: getContractAbi('LiquidityHolding'),
    address: liquidityHolding.address,
    deployTransaction: liquidityHolding.deployTransaction,
  }
  deployData['TransferFee'] = {
    abi: getContractAbi('TransferFee'),
    address: transferFee.address,
    deployTransaction: transferFee.deployTransaction,
  }
  log((await hpl.stakingRewardTreasury()).toString())
  saveDeploymentData(chainId, deployData);
  log('\n  Contract Deployment Data saved to "deployments" directory.');

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
};

module.exports.tags = ['token']
