pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/ILiquidityHolding.sol";
import "../lib/BlackholePrevention.sol";

contract LiquidityHolding is
    Ownable,
    Initializable,
    ILiquidityHolding,
    BlackholePrevention
{
    using SafeERC20 for IERC20;
    IERC20 public hpl;
    bool public swapAndLiquidifyEnabled;
    bool public inSwapAndLiquify;
    IPancakePair public liquidityPair;
    IPancakeRouter02 public pancakeRouter;
    mapping(address => bool) public liquidityCallers;
    uint256 public minimumToAddLiquidity;

    function initialize(address _hpl, address _pancakeRouter)
        external
        initializer
    {
        hpl = IERC20(_hpl);
        liquidityCallers[_hpl] = true;
        minimumToAddLiquidity = 200e18;

        swapAndLiquidifyEnabled = true;
        inSwapAndLiquify = false;
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
    }

    function setHPL(address _hpl) external onlyOwner {
        hpl = IERC20(_hpl);
        liquidityCallers[_hpl] = true;
    }

    function addLiquidity() external override {
        require(liquidityCallers[msg.sender], "not liquidity caller");
        if (
            swapAndLiquidifyEnabled &&
            !inSwapAndLiquify &&
            address(liquidityPair) != address(0)
        ) {
            if (hpl.balanceOf(address(this)) >= minimumToAddLiquidity) {
                swapAndLiquidify(minimumToAddLiquidity);
            }
        }
    }

    function setMinimumToAddLiquidity(uint256 _minimumToAddLiquidity)
        external
        onlyOwner
    {
        minimumToAddLiquidity = _minimumToAddLiquidity;
    }

    function setPancakeRouter(address _pancakeRouter) external onlyOwner {
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
    }

    function setSwapAndLiquidifyEnabled(bool _swapAndLiquidifyEnabled)
        external
        onlyOwner
    {
        swapAndLiquidifyEnabled = _swapAndLiquidifyEnabled;
    }

    function setLiquidityPair(address _liquidityPair) external onlyOwner {
        liquidityPair = IPancakePair(_liquidityPair);
        if (_liquidityPair != address(0)) {
            require(
                liquidityPair.token0() == address(hpl) ||    // huong
                    liquidityPair.token1() == address(hpl),   // huong
                "One of paired tokens must be HPL"
            );
        }
    }

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function swapAndLiquidify(uint256 _amount) internal lockTheSwap {
        // split the contract balance into halves
        uint256 half = _amount / 2;
        uint256 otherHalf = _amount - half;

        // swap tokens
        swapTokensForToken(half);

        // add liquidity to pancake
        addLiquidityInternal(otherHalf);
    }

    function swapTokensForToken(uint256 tokenAmount) private {
        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(hpl);    //
        path[1] = liquidityPair.token0() == address(hpl)   // huong
            ? liquidityPair.token1()
            : liquidityPair.token0();

        IERC20(hpl).approve(address(pancakeRouter), tokenAmount);

        // make the swap
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of other token
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidityInternal(uint256 tokenAmount) private {
        address otherToken = liquidityPair.token0() == address(hpl) // huong 
            ? liquidityPair.token1()
            : liquidityPair.token0();
        uint256 otherTokenAmount = IERC20(otherToken).balanceOf(address(this));
        IERC20(otherToken).approve(
            address(pancakeRouter),
            otherTokenAmount
        );
        // approve token transfer to cover all possible scenarios
        IERC20(hpl).approve(address(pancakeRouter), tokenAmount);

        // add the liquidity
        pancakeRouter.addLiquidity(
            address(hpl),   //huong
            otherToken,
            tokenAmount,
            otherTokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    //rescue token
    function withdrawEther(address payable receiver, uint256 amount)
        external
        virtual
        onlyOwner
    {
        _withdrawEther(receiver, amount);
    }

    function withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external virtual onlyOwner {
        _withdrawERC20(receiver, tokenAddress, amount);
    }

    function withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId
    ) external virtual onlyOwner {
        _withdrawERC721(receiver, tokenAddress, tokenId);
    }
}
