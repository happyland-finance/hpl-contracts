pragma solidity ^0.8.0;

interface IWareHouse {
    function mint(
        address _recipient
    ) external returns (uint256 _tokenId);
}