pragma solidity ^0.8.0;

interface IRewardDistributor {
    function distributeReward(address _recipient, uint256 _hpl, uint256 _hpw) external;
}