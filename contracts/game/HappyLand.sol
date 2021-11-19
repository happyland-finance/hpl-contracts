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

contract HappyLand is Initializable, OwnableUpgradeable, UUPSUpgradeable, SignerRecover {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    IERC20Upgradeable public hpl;
    IERC20Upgradeable public hpw;
    IERC721Upgradeable public land;
    IERC721Upgradeable public house;
    address public operator;

    struct UserInfo {
        uint256 depositedHPL;
        uint256 depositedHPW;
        uint256[] depositedLands;
        mapping(uint256 => uint256) landIdToIndex;  //index + 1
        uint256[] depositedHouses;
        mapping(uint256 => uint256) houseIdToIndex;  //index + 1
        uint256 lastUpdatedAt;
    }

    mapping(address => UserInfo) public userInfo;

    //events
    event TokenDeposit(address depositor, uint256 hplAmount, uint256 hpwAmount);
    event NFTDeposit(address depositor, bytes lands, bytes houses);
    event NFTWithdraw(address withdrawer, bytes lands, bytes houses);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        IERC20Upgradeable _hpl,
        IERC20Upgradeable _hpw,
        IERC721Upgradeable _land,
        IERC721Upgradeable _house,
        address _operator
    ) external initializer {
        __Ownable_init();

        hpl = _hpl;
        hpw = _hpw;
        land = _land;
        house = _house;
        operator = _operator;
    }

    function setOperator(address _op) external onlyOwner {
        operator = _op;
    }

    function depositTokensToPlay(uint256 _hplAmount, uint256 _hpwAmount) external {
        hpl.safeTransferFrom(msg.sender, address(this), _hplAmount);
        hpw.safeTransferFrom(msg.sender, address(this), _hpwAmount);
        userInfo[msg.sender].depositedHPL += _hplAmount;
        userInfo[msg.sender].depositedHPW += _hpwAmount;
        userInfo[msg.sender].lastUpdatedAt = block.timestamp;
        emit TokenDeposit(msg.sender, _hplAmount, _hpwAmount);
    }

    function depositNFTsToPlay(uint256[] memory _lands, uint256[] memory _houses) external {
        UserInfo storage _user = userInfo[msg.sender];
        for(uint256 i = 0; i < _lands.length; i++) {
            land.safeTransferFrom(msg.sender, address(this), _lands[i]);
            _user.depositedLands.push(_lands[i]);
            _user.landIdToIndex[_lands[i]] = _user.depositedLands.length;
        }

        for(uint256 i = 0; i < _houses.length; i++) {
            house.safeTransferFrom(msg.sender, address(this), _houses[i]);
            _user.depositedHouses.push(_houses[i]);
            _user.houseIdToIndex[_houses[i]] = _user.depositedHouses.length;
        }
        userInfo[msg.sender].lastUpdatedAt = block.timestamp;

        emit NFTDeposit(msg.sender, abi.encodePacked(_lands), abi.encodePacked(_houses));
    }

    function withdrawNFTs(uint256[] memory _lands, uint256[] memory _houses, uint256 _expiredTime, bytes32 r, bytes32 s, uint8 v) external {
        require(block.timestamp < _expiredTime, "withdrawNFTs: !expired");
        bytes32 msgHash = keccak256(abi.encode(msg.sender, _lands, _houses, _expiredTime));
        require(operator == recoverSigner(r, s, v, msgHash), "invalid operator");
        UserInfo storage _user = userInfo[msg.sender];
        for(uint256 i = 0; i < _lands.length; i++) {
            require(_user.landIdToIndex[_lands[i]] > 0, "invalid land tokenId");
            land.safeTransferFrom(address(this), msg.sender, _lands[i]);
            //swap 
            uint256 _index = _user.landIdToIndex[_lands[i]] - 1;
            _user.depositedLands[_index] = _user.depositedLands[_user.depositedLands.length - 1];
            _user.landIdToIndex[_user.depositedLands[_index]] = _index + 1;
            _user.depositedLands.pop();

            delete _user.landIdToIndex[_lands[i]];
        }

        for(uint256 i = 0; i < _houses.length; i++) {
            require(_user.houseIdToIndex[_houses[i]] > 0, "invalid land tokenId");
            house.safeTransferFrom(address(this), msg.sender, _houses[i]);
            //swap 
            uint256 _index = _user.houseIdToIndex[_houses[i]] - 1;
            _user.depositedHouses[_index] = _user.depositedHouses[_user.depositedHouses.length - 1];
            _user.houseIdToIndex[_user.depositedHouses[_index]] = _index + 1;
            _user.depositedHouses.pop();

            delete _user.houseIdToIndex[_houses[i]];
        }
        userInfo[msg.sender].lastUpdatedAt = block.timestamp;
        emit NFTWithdraw(msg.sender, abi.encodePacked(_lands), abi.encodePacked(_houses));
    }
}
