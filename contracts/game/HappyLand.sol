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

contract HappyLand is Upgradeable, SignerRecover {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    IERC20Upgradeable public hpl;
    IERC20Upgradeable public hpw;
    IERC721Upgradeable public land;
    address public operator;

    struct UserInfo {
        uint256 hplDeposit;
        uint256 hpwDeposit;
        uint256[] depositedLands;
        mapping(uint256 => uint256) landIdToIndex; //index + 1
        uint256 lastUpdatedAt;
        uint256 hplRewardClaimed;
        uint256 hpwRewardClaimed;
    }

    mapping(address => UserInfo) public userInfo;

    //events
    event TokenDeposit(address depositor, uint256 hplAmount, uint256 hpwAmount);
    event TokenWithdraw(
        address withdrawer,
        uint256 hplAmount,
        uint256 hpwAmount
    );
    event NFTDeposit(address depositor, bytes lands);
    event NFTWithdraw(address withdrawer, bytes lands);

    event RewardsClaimed(address claimer, uint256 hplAmount, uint256 hpwAmount);

    function initialize(
        IERC20Upgradeable _hpl,
        IERC20Upgradeable _hpw,
        IERC721Upgradeable _land,
        address _operator
    ) external initializer {
        __Ownable_init();

        hpl = _hpl;
        hpw = _hpw;
        land = _land;
        operator = _operator;
    }

    function setOperator(address _op) external onlyOwner {
        operator = _op;
    }

    function depositTokensToPlay(uint256 _hplAmount, uint256 _hpwAmount)
        external
    {
        hpl.safeTransferFrom(msg.sender, address(this), _hplAmount);
        hpw.safeTransferFrom(msg.sender, address(this), _hpwAmount);
        userInfo[msg.sender].hplDeposit += _hplAmount;
        userInfo[msg.sender].hpwDeposit += _hpwAmount;
        userInfo[msg.sender].lastUpdatedAt = block.timestamp;
        emit TokenDeposit(msg.sender, _hplAmount, _hpwAmount);
    }

    function depositNFTsToPlay(uint256[] memory _lands) external {
        UserInfo storage _user = userInfo[msg.sender];
        for (uint256 i = 0; i < _lands.length; i++) {
            land.safeTransferFrom(msg.sender, address(this), _lands[i]);
            _user.depositedLands.push(_lands[i]);
            _user.landIdToIndex[_lands[i]] = _user.depositedLands.length;
        }

        userInfo[msg.sender].lastUpdatedAt = block.timestamp;

        emit NFTDeposit(msg.sender, abi.encodePacked(_lands));
    }

    function withdrawNFTs(
        uint256[] memory _lands,
        uint256 _expiredTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(block.timestamp < _expiredTime, "withdrawNFTs: !expired");
        bytes32 msgHash = keccak256(
            abi.encode(msg.sender, _lands, _expiredTime)
        );
        require(
            operator == recoverSigner(r, s, v, msgHash),
            "invalid operator"
        );
        UserInfo storage _user = userInfo[msg.sender];
        for (uint256 i = 0; i < _lands.length; i++) {
            require(_user.landIdToIndex[_lands[i]] > 0, "invalid land tokenId");
            land.safeTransferFrom(address(this), msg.sender, _lands[i]);
            //swap
            uint256 _index = _user.landIdToIndex[_lands[i]] - 1;
            _user.depositedLands[_index] = _user.depositedLands[
                _user.depositedLands.length - 1
            ];
            _user.landIdToIndex[_user.depositedLands[_index]] = _index + 1;
            _user.depositedLands.pop();

            delete _user.landIdToIndex[_lands[i]];
        }

        userInfo[msg.sender].lastUpdatedAt = block.timestamp;
        emit NFTWithdraw(msg.sender, abi.encodePacked(_lands));
    }

    function withdrawTokens(
        uint256 _hplSpent,
        uint256 _hpwSpent,
        uint256 _expiredTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(block.timestamp < _expiredTime, "withdrawTokens: !expired");
        bytes32 msgHash = keccak256(
            abi.encode(msg.sender, _hplSpent, _hpwSpent, _expiredTime)
        );
        require(
            operator == recoverSigner(r, s, v, msgHash),
            "invalid operator"
        );
        UserInfo storage _user = userInfo[msg.sender];

        require(_user.hplDeposit >= _hplSpent, "invalid hplSpent");
        require(_user.hpwDeposit >= _hpwSpent, "invalid hpwSpent");

        //return hpl
        hpl.safeTransfer(msg.sender, _user.hplDeposit - _hplSpent);

        //return hpw
        hpw.safeTransfer(msg.sender, _user.hpwDeposit - _hpwSpent);

        //burn hplSpent and hpwSpent
        IBurn(address(hpl)).burn(_hplSpent);
        IBurn(address(hpw)).burn(_hpwSpent);

        emit TokenWithdraw(
            msg.sender,
            _user.hplDeposit - _hplSpent,
            _user.hpwDeposit - _hpwSpent
        );

        _user.hplDeposit = _hplSpent;
        _user.hpwDeposit = _hpwSpent;

        _user.lastUpdatedAt = block.timestamp;
    }

    function claimRewards(
        uint256 _hplRewards,
        uint256 _hpwRewards,
        uint256 _expiredTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(block.timestamp < _expiredTime, "claimRewards: !expired");
        bytes32 msgHash = keccak256(
            abi.encode(msg.sender, _hplRewards, _hpwRewards, _expiredTime)
        );
        require(
            operator == recoverSigner(r, s, v, msgHash),
            "invalid operator"
        );
        UserInfo storage _user = userInfo[msg.sender];

        require(_user.hplRewardClaimed < _hplRewards, "invalid _hplRewards");
        require(_user.hpwRewardClaimed < _hpwRewards, "invalid _hpwRewards");

        uint256 toTransferHpl = _hplRewards - _user.hplRewardClaimed;
        uint256 toTransferHpw = _hpwRewards - _user.hpwRewardClaimed;

        _user.hplRewardClaimed = _hplRewards;
        _user.hpwRewardClaimed = _hpwRewards;

        hpl.safeTransfer(msg.sender, toTransferHpl);
        hpw.safeTransfer(msg.sender, toTransferHpw);

        emit RewardsClaimed(msg.sender, toTransferHpl, toTransferHpw);
    }
}
