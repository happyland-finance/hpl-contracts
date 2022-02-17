pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../lib/SignerRecover.sol";
import "../interfaces/IBurn.sol";
import "../lib/Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "../interfaces/IMint.sol";

contract LandExpand is Upgradeable, SignerRecover, IERC721ReceiverUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    IERC20Upgradeable public hpl;
    IERC20Upgradeable public hpw;
    IERC721Upgradeable public land;
    address public operator;
    uint256 public constant DESSERT_LAND_ID_START = 10000000;
    uint256 public dessertLandCurrentTokenId;
    mapping(uint256 => bool) public dessertLandTokens;
    mapping(uint256 => uint256) public usedLands;
    uint256 public hplExpandFee;
    uint256 public hpwExpandFee;
    uint256 public breedingPeriod;

    function initialize(
        IERC20Upgradeable _hpl,
        IERC20Upgradeable _hpw,
        IERC721Upgradeable _land,
        uint256 _hplExpandFee,
        uint256 _hpwExpandFee,
        address _operator
    ) external initializer {
        initOwner();

        hpl = _hpl;
        hpw = _hpw;
        land = _land;
        dessertLandCurrentTokenId = DESSERT_LAND_ID_START;

        hplExpandFee = _hplExpandFee;
        hpwExpandFee = _hpwExpandFee;

        breedingPeriod = 1 days;
        if (getChainId() != 56) {
            breedingPeriod = 10 minutes;
        }
        operator = _operator;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        //do nothing
        return bytes4("");
    }

    function getChainId() public view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}