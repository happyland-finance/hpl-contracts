pragma solidity ^0.8.0;

interface ITokenHook {
    function addLiquidity() external;
    function getTransferFees(address sender, address recipient, uint256 amount) external view returns (uint256 stakeRewardFee, uint256 liquidityFee, uint256 burnFee);
}