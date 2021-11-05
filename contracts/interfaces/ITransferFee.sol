pragma solidity ^0.8.0;

interface ITransferFee {
    function getTransferFees(address sender, address recipient, uint256 amount) external view returns (uint256 stakeRewardFee, uint256 liquidityFee, uint256 burnFee);
}