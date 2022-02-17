pragma solidity ^0.8.0;

interface ILandSale {
    function mint(address _recipient, uint256 _tokenId)
        external
        returns (uint256 tokenId);
}
