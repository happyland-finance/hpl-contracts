pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../lib/SignerRecover.sol";
import "../interfaces/IBurn.sol";
import "../lib/Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "../interfaces/ILandSale.sol";

contract LandExpand is Upgradeable, SignerRecover, IERC721ReceiverUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    struct Breed {
        bool open;
        bool success;
        uint256 createdTokenId;
        address owner;
        uint256 land1;
        uint256 land2;
        bytes32 commitment;
        uint256 successRatePercentage;
        uint256 createdAt;
        bytes32 bHash;
    }

    IERC20Upgradeable public hpl;
    IERC20Upgradeable public hpw;
    IERC721Upgradeable public land;
    address public operator;
    uint256 public constant WILD_LAND_ID_START = 10000000;
    uint256 public wildLandCurrentTokenId;
    mapping(uint256 => bool) public wildLandTokens;
    mapping(uint256 => uint256) public usedLands;
    uint256 public hplExpandFee;
    uint256 public hpwExpandFee;
    uint256 public breedingPeriod;
    mapping(address => bytes32[]) public breedCommitList;
    mapping(bytes32 => Breed) public breedInfo;
    ILandSale public landSale;
    uint256 public maxUsedLandCount;

    function initialize(
        IERC20Upgradeable _hpl,
        IERC20Upgradeable _hpw,
        IERC721Upgradeable _land,
        uint256 _hplExpandFee,
        uint256 _hpwExpandFee,
        address _landSale,
        address _operator
    ) external initializer {
        initOwner();

        hpl = _hpl;
        hpw = _hpw;
        land = _land;
        wildLandCurrentTokenId = WILD_LAND_ID_START;

        hplExpandFee = _hplExpandFee;
        hpwExpandFee = _hpwExpandFee;

        breedingPeriod = 1 days;
        if (getChainId() != 56) {
            breedingPeriod = 10 minutes;
        }
        operator = _operator;

        landSale = ILandSale(_landSale);
        maxUsedLandCount = 1;
    }

    function createBreed(uint256 _land1, uint256 _land2, uint256 _successRatePercentage, bytes32 _commitment, uint256 _expired, bytes32 _r, bytes32 _s, uint8 _v) external {
        require(_expired > block.timestamp, "expired");
        //verifying signature
        bytes32 message = keccak256(
            abi.encode(
                msg.sender,
                _land1,
                _land2,
                _successRatePercentage,
                _commitment,
                _expired
            )
        );
        require(
            operator == recoverSigner(_r, _s, _v, message),
            "invalid operator"
        );

        require(usedLands[_land1] < maxUsedLandCount, "used land1");
        require(usedLands[_land2] < maxUsedLandCount, "used land2");

        require(!wildLandTokens[_land1], "wildLandTokens1");
        require(!wildLandTokens[_land2], "wildLandTokens2");

        require(breedInfo[_commitment].owner == address(0) , "commitment used");

        //transfer fee tokens
        hpl.safeTransferFrom(msg.sender, address(this), hplExpandFee);
        hpw.safeTransferFrom(msg.sender, address(this), hpwExpandFee);

        //burn hpw
        IBurn(address(hpw)).burn(hpwExpandFee);

        //lock lands
        land.transferFrom(msg.sender, address(this), _land1);
        land.transferFrom(msg.sender, address(this), _land2);

        //save info
        breedCommitList[msg.sender].push(_commitment);
        breedInfo[_commitment] = Breed({
            open: false,
            success: false,
            createdTokenId: 0,
            owner: msg.sender, 
            land1: _land1,
            land2: _land2,
            commitment: _commitment,
            successRatePercentage: _successRatePercentage,
            createdAt: block.timestamp,
            bHash: blockhash(block.number)
        });
    }

    function openBreed(bytes32 _secret) external {
        bytes32 _commitment = keccak256(abi.encode(_secret));
        Breed storage _breed = breedInfo[_commitment];
        require(!_breed.open && _breed.owner != address(0), "breed open or not exist");
        require(_breed.createdAt + breedingPeriod <= block.timestamp, "!breedingPeriod");
        _breed.open = true;

        bytes32 h = keccak256(abi.encode(_secret, _breed.bHash, _breed.createdAt));
        uint256 random = uint256(h).mod(100);

        if (random < _breed.successRatePercentage) {
            //success
            _breed.success = true;
            //mint token
            wildLandCurrentTokenId++;
            landSale.mint(_breed.owner, wildLandCurrentTokenId);
            _breed.createdTokenId = wildLandCurrentTokenId;

            //mark used lands
            usedLands[_breed.land1]++;
            usedLands[_breed.land2]++;
        } else {
            //do nothing
        }

        //return land
        land.transferFrom(address(this), _breed.owner, _breed.land1);
        land.transferFrom(address(this), _breed.owner, _breed.land2);
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