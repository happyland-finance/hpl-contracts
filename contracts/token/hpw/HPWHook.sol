pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../interfaces/IPancakePair.sol";
import "../../interfaces/IPancakeRouter02.sol";
import "../../interfaces/ITokenHook.sol";
import "../../lib/BlackholePrevention.sol";
import "../../lib/Upgradeable.sol";

contract HPWHook is
    Upgradeable,
    ITokenHook,
    BlackholePrevention
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    IERC20Upgradeable public hpw;
    bool public swapAndLiquidifyEnabled;
    bool public inSwapAndLiquify;
    IPancakePair public liquidityPair;
    IPancakeRouter02 public pancakeRouter;
    mapping(address => bool) public liquidityCallers;
    uint256 public minimumToAddLiquidity;

    mapping(address => bool) public zeroFeeList;

    event ZeroFeeList(address _addr, bool val);
    uint256 public stakeRewardFee;
    uint256 public liquidityFee;
    uint256 public burnFee;

    function initialize(address _pancakeRouter)
        external
        initializer
    {
        initOwner();
        zeroFeeList[msg.sender] = true;
        stakeRewardFee = 0;
        liquidityFee = 300;
        burnFee = 200;

        minimumToAddLiquidity = 200e18;

        swapAndLiquidifyEnabled = true;
        inSwapAndLiquify = false;
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
    }

    function setHPW(address _hpw) external onlyOwner {
        hpw = IERC20Upgradeable(_hpw);
        liquidityCallers[_hpw] = true;
    }

    function addLiquidity() external override {
        require(liquidityCallers[msg.sender], "not liquidity caller");
        if (
            swapAndLiquidifyEnabled &&
            !inSwapAndLiquify &&
            address(liquidityPair) != address(0)
        ) {
            if (hpw.balanceOf(address(this)) >= minimumToAddLiquidity) {
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
                liquidityPair.token0() == address(hpw) ||    // huong
                    liquidityPair.token1() == address(hpw),   // huong
                "One of paired tokens must be HPW"
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
        path[0] = address(hpw);    //
        path[1] = liquidityPair.token0() == address(hpw)   // huong
            ? liquidityPair.token1()
            : liquidityPair.token0();

        IERC20Upgradeable(hpw).approve(address(pancakeRouter), tokenAmount);

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
        address otherToken = liquidityPair.token0() == address(hpw) // huong 
            ? liquidityPair.token1()
            : liquidityPair.token0();
        uint256 otherTokenAmount = IERC20Upgradeable(otherToken).balanceOf(address(this));
        IERC20Upgradeable(otherToken).approve(
            address(pancakeRouter),
            otherTokenAmount
        );
        // approve token transfer to cover all possible scenarios
        IERC20Upgradeable(hpw).approve(address(pancakeRouter), tokenAmount);

        // add the liquidity
        pancakeRouter.addLiquidity(
            address(hpw),   //huong
            otherToken,
            tokenAmount,
            otherTokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function setZeroFeeList(address[] memory _addrs, bool _val)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            zeroFeeList[_addrs[i]] = _val;
            emit ZeroFeeList(_addrs[i], _val);
        }
    }

    function setTransferFees(
        uint256 _stakeRewardFee,
        uint256 _liquidityFee,
        uint256 _burnFee
    ) external onlyOwner {
        stakeRewardFee = _stakeRewardFee;
        liquidityFee = _liquidityFee;
        burnFee = _burnFee;
    }

    function getTransferFees(
        address sender,
        address recipient,
        uint256 amount
    )
        external
        view
        override
        returns (
            uint256 _stakeRewardFee,
            uint256 _liquidityFee,
            uint256 _burnFee
        )
    {
        if (zeroFeeList[sender] || zeroFeeList[recipient]) return (0, 0, 0);
        return (stakeRewardFee, liquidityFee, burnFee); //0.5%
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
