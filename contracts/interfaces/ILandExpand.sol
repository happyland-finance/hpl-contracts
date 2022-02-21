pragma solidity ^0.8.0;

interface ILandExpand {
    function wildLandTokens(uint256 _tokenId) external view returns (bool);

    function usedLands(uint256 _tokenId) external view returns (uint256);
}
