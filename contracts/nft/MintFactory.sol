pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../lib/Upgradeable.sol";
import "../interfaces/ILand.sol";
import "../lib/BlackholePreventionUpgradeable.sol";

contract MintFactory is
    Upgradeable,
    BlackholePreventionUpgradeable
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    ILand public land;
    mapping(address => bool) public minters;

    event SetMinter(address minter, bool val);

    function initialize(ILand _land) external initializer {
        initOwner();

        land = _land;
    }

    function setMinters(address[] memory _minters, bool _val) external onlyOwner {
        for(uint256 i = 0; i < _minters.length; i++) {
            minters[_minters[i]] = _val;
            emit SetMinter(_minters[i], _val);
        }
    }

    function mint(address _recipient, uint256 _tokenId) external {
        require(minters[msg.sender], "!minter");
        land.mint(_recipient, _tokenId);
    }
}