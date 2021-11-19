const { expect } = require('chai')
const { ethers, upgrades } = require('hardhat')
const IPancakeRouter02ABI = require('../abi/IPancakeRouter02.json')
const IPancakeRouterFactoryABI = require('../abi/IPancakeFactory.json')

const IERC20ABI = require('../abi/IERC20.json')
const IPancakePair = require('../abi/IPancakePair.json')

const BigNumber = ethers.BigNumber
function toWei(n) {
  return ethers.utils.parseEther(n)
}
describe('MasterChef', async function () {
  const [owner, tokenReceiver, stakingRewardTreasury, liquidityReceiver, user1, user2, user3, user4, user5, user6] = await ethers.getSigners()
  provider = ethers.provider;
  let hpl, hpw, transferFee, transferFeeHPW, liquidityHoding, liquidityHodingHPW, lp1, lp2, tokenLock
  let deadline = 999999999999
  beforeEach(async () => {
    const TransferFee = await ethers.getContractFactory("TransferFee")
    let TransferFeeInstance = await TransferFee.deploy()
    transferFee = await TransferFeeInstance.deployed()
    await transferFee.setZeroFeeList([tokenReceiver.address], true)
    //liquidityHoding
    let liquidityHoding_ = await ethers.getContractFactory('LiquidityHolding')
    let liquidityHodingInstance = await liquidityHoding_.deploy();
    liquidityHoding = await liquidityHodingInstance.deployed();
    //uniswap v2
    pancakeRouter = await ethers.getContractAt(IPancakeRouter02ABI, "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")
    pancakeFactory = await ethers.getContractAt(IPancakeRouterFactoryABI, "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f")
    let wethAddress = await pancakeRouter.WETH()
    weth = await ethers.getContractAt(IERC20ABI, wethAddress)
    usdt = await ethers.getContractAt(IERC20ABI, "0xdac17f958d2ee523a2206206994597c13d831ec7")

    //grab some mock token
    let ERC20Mock = await ethers.getContractFactory("ERC20Mock")
    let ERC20MockInstance = await ERC20Mock.deploy()
    erc20Mock = await ERC20MockInstance.deployed()

    const HPL = await ethers.getContractFactory('HPL')
    hpl = await upgrades.deployProxy(HPL, [tokenReceiver.address, stakingRewardTreasury.address, liquidityHoding.address, transferFee.address], { unsafeAllow: ['delegatecall'], kind: 'uups' }) //unsafeAllowCustomTypes: true,
    expect(await hpl.balanceOf(tokenReceiver.address)).to.be.equal(ethers.utils.parseEther('500000000'))
    await liquidityHoding.initialize(hpl.address, pancakeRouter.address)

  })

  it('Transfer normal with fees', async function () {
    await hpl.connect(tokenReceiver).transfer(user1.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user2.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user3.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user4.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user5.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user6.address, 10000)

    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000)

    await hpl.connect(user1).transfer(user1.address, 10000)
    await hpl.connect(user2).transfer(user2.address, 10000)
    await hpl.connect(user3).transfer(user3.address, 10000)
    await hpl.connect(user4).transfer(user4.address, 10000)
    await hpl.connect(user5).transfer(user5.address, 10000)
    await hpl.connect(user6).transfer(user6.address, 10000)

    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000 * 0.985)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000 * 0.985)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000 * 0.985)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000 * 0.985)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000 * 0.985)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000 * 0.985)

    expect(await hpl.balanceOf(stakingRewardTreasury.address)).to.be.equal(300)
    expect(await hpl.totalSupply()).to.be.equal(BigNumber.from(ethers.utils.parseEther('500000000')).sub(300))
    expect(await hpl.balanceOf(liquidityHoding.address)).to.be.equal(300)
  })

  it('Transfer normal without fees', async function () {
    await hpl.setTransferFee(ethers.constants.AddressZero)

    await hpl.connect(tokenReceiver).transfer(user1.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user2.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user3.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user4.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user5.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user6.address, 10000)

    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000)

    await hpl.connect(user1).transfer(user1.address, 10000)
    await hpl.connect(user2).transfer(user2.address, 10000)
    await hpl.connect(user3).transfer(user3.address, 10000)
    await hpl.connect(user4).transfer(user4.address, 10000)
    await hpl.connect(user5).transfer(user5.address, 10000)
    await hpl.connect(user6).transfer(user6.address, 10000)

    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000)

    expect(await hpl.balanceOf(stakingRewardTreasury.address)).to.be.equal(0)
    expect(await hpl.totalSupply()).to.be.equal(BigNumber.from(ethers.utils.parseEther('500000000')).sub(0))
    expect(await hpl.balanceOf(liquidityHoding.address)).to.be.equal(0)
  })
  it('Transfer normal set stakeRewardFee 0', async function () {
    await transferFee.setTransferFees(0,50,50);

    await hpl.connect(tokenReceiver).transfer(user1.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user2.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user3.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user4.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user5.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user6.address, 10000)

    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000)

    await hpl.connect(user1).transfer(user1.address, 10000)
    await hpl.connect(user2).transfer(user2.address, 10000)
    await hpl.connect(user3).transfer(user3.address, 10000)
    await hpl.connect(user4).transfer(user4.address, 10000)
    await hpl.connect(user5).transfer(user5.address, 10000)
    await hpl.connect(user6).transfer(user6.address, 10000)

    
    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000*0.990)

    expect(await hpl.balanceOf(stakingRewardTreasury.address)).to.be.equal(0)
    expect(await hpl.totalSupply()).to.be.equal(BigNumber.from(ethers.utils.parseEther('500000000')).sub(300))
    expect(await hpl.balanceOf(liquidityHoding.address)).to.be.equal(300)
  })
  it('Transfer normal set liquidityFee 0', async function () {
    await transferFee.setTransferFees(50,0,50);

    await hpl.connect(tokenReceiver).transfer(user1.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user2.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user3.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user4.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user5.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user6.address, 10000)

    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000)

    await hpl.connect(user1).transfer(user1.address, 10000)
    await hpl.connect(user2).transfer(user2.address, 10000)
    await hpl.connect(user3).transfer(user3.address, 10000)
    await hpl.connect(user4).transfer(user4.address, 10000)
    await hpl.connect(user5).transfer(user5.address, 10000)
    await hpl.connect(user6).transfer(user6.address, 10000)

    
    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000*0.990)

    expect(await hpl.balanceOf(stakingRewardTreasury.address)).to.be.equal(300)
    expect(await hpl.totalSupply()).to.be.equal(BigNumber.from(ethers.utils.parseEther('500000000')).sub(300))
    expect(await hpl.balanceOf(liquidityHoding.address)).to.be.equal(0)
  })
  it('Transfer normal set burnFee 0', async function () {
    await transferFee.setTransferFees(50,50,0);

    await hpl.connect(tokenReceiver).transfer(user1.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user2.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user3.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user4.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user5.address, 10000)
    await hpl.connect(tokenReceiver).transfer(user6.address, 10000)

    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000)

    await hpl.connect(user1).transfer(user1.address, 10000)
    await hpl.connect(user2).transfer(user2.address, 10000)
    await hpl.connect(user3).transfer(user3.address, 10000)
    await hpl.connect(user4).transfer(user4.address, 10000)
    await hpl.connect(user5).transfer(user5.address, 10000)
    await hpl.connect(user6).transfer(user6.address, 10000)

    
    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user2.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user3.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user4.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user5.address)).to.be.equal(10000*0.990)
    expect(await hpl.balanceOf(user6.address)).to.be.equal(10000*0.990)

    expect(await hpl.balanceOf(stakingRewardTreasury.address)).to.be.equal(300)
    expect(await hpl.totalSupply()).to.be.equal(BigNumber.from(ethers.utils.parseEther('500000000')).sub(0))
    expect(await hpl.balanceOf(liquidityHoding.address)).to.be.equal(300)
  })

  it('Add & Remove liquidity Any Token', async function () {
    await erc20Mock.transfer(user1.address, BigNumber.from(10).pow(18).mul(100000))
    await erc20Mock.connect(user1).approve(pancakeRouter.address, BigNumber.from(10).pow(18).mul(100000))

    await hpl.connect(tokenReceiver).transfer(user1.address, BigNumber.from(10).pow(18).mul(100000))
    await hpl.connect(user1).approve(pancakeRouter.address, BigNumber.from(10).pow(18).mul(100000))

    await pancakeRouter.connect(user1).addLiquidity(erc20Mock.address, hpl.address, BigNumber.from(10).pow(18).mul(1000), BigNumber.from(10).pow(18).mul(100000), 0, 0, user1.address, +new Date)
    const getPairAddress = await pancakeFactory.getPair(erc20Mock.address, hpl.address);
    lpToken = await ethers.getContractAt(IPancakePair, getPairAddress)
    expect(await lpToken.balanceOf(user1.address)).to.above(0)
    let hplBalanceBefore = await hpl.balanceOf(user1.address);
    await pancakeRouter.connect(user1).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      1000,
      0,
      [erc20Mock.address, hpl.address],
      user1.address,
      +new Date
    )
    let hplBalanceAfter = await hpl.balanceOf(user1.address);
    expect(hplBalanceAfter).to.above(hplBalanceBefore);

    //removing liquidity

    const user1LpTokenBalance = await lpToken.balanceOf(user1.address)
    await lpToken.connect(user1).approve(pancakeRouter.address, user1LpTokenBalance.toString())
    hplBalanceBefore = await hpl.balanceOf(user1.address)
    let erc20MockBalanceBefore = await erc20Mock.balanceOf(user1.address)
    await pancakeRouter.connect(user1).removeLiquidity(erc20Mock.address, hpl.address, user1LpTokenBalance.toString(), 0, 0, user1.address, +new Date)
    hplBalanceAfter = await hpl.balanceOf(user1.address)
    let erc20MockBalanceAfter = await erc20Mock.balanceOf(user1.address)
    expect(hplBalanceAfter).to.above(hplBalanceBefore);
    expect(erc20MockBalanceAfter).to.above(erc20MockBalanceBefore);

    expect(await lpToken.balanceOf(user1.address)).to.be.equal(0);
  })
  it('Add & Remove liquidity weth-hpl', async function () {

    await hpl.connect(tokenReceiver).transfer(user1.address, BigNumber.from(10).pow(18).mul(100000))
    await hpl.connect(user1).approve(pancakeRouter.address, BigNumber.from(10).pow(18).mul(100000))

    await pancakeRouter.connect(user1).addLiquidityETH(hpl.address, BigNumber.from(10).pow(18).mul(100000), 0, 0, user1.address, +new Date, { value: ethers.utils.parseEther("5") }) //, { value: ethers.utils.parseEther("0.5") }
    const getPairAddress = await pancakeFactory.getPair(weth.address, hpl.address);
    let lpToken1 = await ethers.getContractAt(IPancakePair, getPairAddress)
    expect(await lpToken1.balanceOf(user1.address)).to.above(0)

    const hplBalanceBefore = await hpl.balanceOf(user2.address);
    await pancakeRouter.connect(user2).swapExactETHForTokensSupportingFeeOnTransferTokens(
      0,
      [weth.address, hpl.address],
      user2.address,
      +new Date,
      { value: ethers.utils.parseEther("0.5") }
    )
    const hplBalanceAfter = await hpl.balanceOf(user2.address);
    expect(hplBalanceAfter).to.above(hplBalanceBefore);

    //removing liquidity
    const user1LpTokenBalance = await lpToken1.balanceOf(user1.address)
    await lpToken1.connect(user1).approve(pancakeRouter.address, user1LpTokenBalance.toString())
    expect(await hpl.balanceOf(user1.address)).to.be.equal(0);
    const wethBalanceBefore = await provider.getBalance(user1.address);
    await pancakeRouter.connect(user1).removeLiquidityETHSupportingFeeOnTransferTokens(hpl.address, user1LpTokenBalance.toString(), 0, 0, user1.address, +new Date)
    const wethBalanceAfter = await provider.getBalance(user1.address);
    expect(wethBalanceAfter).to.above(wethBalanceBefore);
    expect(await await hpl.balanceOf(user1.address)).to.above(0)
    expect(await lpToken1.balanceOf(user1.address)).to.be.equal(0);
  })
  it('swapAndLiquidify', async function () {
    await hpl.connect(tokenReceiver).transfer(user2.address, BigNumber.from(10).pow(18).mul(2000000))
    await erc20Mock.transfer(tokenReceiver.address, BigNumber.from(10).pow(18).mul(1000000))
    await erc20Mock.connect(tokenReceiver).approve(pancakeRouter.address, BigNumber.from(10).pow(18).mul(1000000))
    await hpl.connect(tokenReceiver).approve(pancakeRouter.address, BigNumber.from(10).pow(18).mul(2000000))

    await pancakeRouter.connect(tokenReceiver).addLiquidity(erc20Mock.address, hpl.address, BigNumber.from(10).pow(18).mul(1000000), BigNumber.from(10).pow(18).mul(2000000), 0, 0, user1.address, +new Date)


    const getPairAddress_ = await pancakeFactory.getPair(erc20Mock.address, hpl.address);
    lpToken = await ethers.getContractAt(IPancakePair, getPairAddress_)

    await liquidityHoding.setLiquidityPair(getPairAddress_)
    await hpl.connect(owner).setLiquidityHolding(liquidityHoding.address)

    expect(await hpl.balanceOf(liquidityHoding.address)).to.be.equal(0);
    await hpl.connect(user2).transfer(user2.address, BigNumber.from(10).pow(18).mul(20000))  //fee = 100e18
    expect(await hpl.balanceOf(liquidityHoding.address)).to.be.equal(BigNumber.from(10).pow(18).mul(100));
    await hpl.connect(user2).transfer(user2.address, BigNumber.from(10).pow(18).mul(20000)) //fee = 100e18
    expect(await hpl.balanceOf(liquidityHoding.address)).to.be.equal(BigNumber.from(10).pow(18).mul(200));
    let liquidityHodingBefore = await lpToken.balanceOf(liquidityHoding.address)
    expect(liquidityHodingBefore).to.be.equal(0)
    await hpl.connect(user2).transfer(user2.address, BigNumber.from(10).pow(18).mul(1))
    let liquidityHodingAfter = await lpToken.balanceOf(liquidityHoding.address)
    expect(liquidityHodingAfter).to.above(liquidityHodingBefore);

    await hpl.connect(user2).transfer(user3.address, BigNumber.from(10).pow(18).mul(60000))   // fee = 300e18
    liquidityHodingBefore = await lpToken.balanceOf(liquidityHoding.address)
    await hpl.connect(user2).transfer(user3.address, BigNumber.from(10).pow(18).mul(1))
    liquidityHodingAfter = await lpToken.balanceOf(liquidityHoding.address)
    expect(liquidityHodingAfter).to.above(liquidityHodingBefore);


  })
  it("totalSupply ,addLiquidityFee, ", async function () {
    await hpl.connect(tokenReceiver).transfer(user1.address, 10000)
    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000)
    const totalSupplyBefore = await hpl.totalSupply();
    const stakingRewardTreasuryBefore = await hpl.balanceOf(stakingRewardTreasury.address);
    const liquidityHodingBefore = await hpl.balanceOf(liquidityHoding.address);

    await hpl.connect(user1).transfer(user1.address, 10000)
    expect(await hpl.balanceOf(user1.address)).to.be.equal(10000 * 0.985)
    const totalSupplyAfter = await hpl.totalSupply();
    const stakingRewardTreasuryAfter = await hpl.balanceOf(stakingRewardTreasury.address);
    const liquidityHodingAfter = await hpl.balanceOf(liquidityHoding.address);

    expect(BigNumber.from(totalSupplyBefore).sub(totalSupplyAfter)).to.equal(10000 * 0.005)
    expect(BigNumber.from(stakingRewardTreasuryAfter).sub(stakingRewardTreasuryBefore)).to.equal(10000 * 0.005)
    expect(BigNumber.from(liquidityHodingAfter).sub(liquidityHodingBefore)).to.equal(10000 * 0.005)

  })

})