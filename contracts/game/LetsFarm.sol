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

contract LetsFarm is Upgradeable, SignerRecover, IERC721ReceiverUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    IERC20Upgradeable public hpl;
    IERC20Upgradeable public hpw;
    address public operator;

    struct UserInfo {
        uint256 hplDeposit;
        uint256 hpwDeposit;
        uint256 lastUpdatedAt;
        uint256 hplRewardClaimed;
        uint256 hpwRewardClaimed;
        uint256 lastRewardClaimedAt;
    }

    struct DepositedNFT {
        uint256[] depositedTokenIds;
        mapping(uint256 => uint256) tokenIdToIndex; //index + 1
    }

    mapping(address => UserInfo) public userInfo;
    //nft => user => DepositedNFT
    mapping(address => mapping(address => DepositedNFT)) nftUserInfo;
    //events
    event TokenDeposit(address depositor, uint256 hplAmount, uint256 hpwAmount);
    event TokenWithdraw(
        address withdrawer,
        uint256 hplAmount,
        uint256 hpwAmount
    );
    event NFTDeposit(address nft, address depositor, bytes tokenIds);
    event NFTWithdraw(address nft, address withdrawer, bytes tokenIds);

    event RewardsClaimed(address claimer, uint256 hplAmount, uint256 hpwAmount);

    struct UserInfoTokenWithdraw {
        uint256 hplWithdraw;
        uint256 hpwWithdraw;
    }
    mapping(address => UserInfoTokenWithdraw) public userInfoTokenWithdraw;

    uint256 public minTimeBetweenClaims;
    uint256 public contractStartAt;

    function initialize(
        IERC20Upgradeable _hpl,
        IERC20Upgradeable _hpw,
        address _operator
    ) external initializer {
        initOwner();

        minTimeBetweenClaims = 10 days;
        contractStartAt = block.timestamp;

        hpl = _hpl;
        hpw = _hpw;
        operator = _operator;
    }

    function setMinTimeBetweenClaims(uint256 _minTimeBetweenClaims)
        external
        onlyOwner
    {
        minTimeBetweenClaims = _minTimeBetweenClaims;
    }

    function setContractStart() external onlyOwner {
        contractStartAt = block.timestamp;
    }

    function setContractStartWithTime(uint256 _time) external onlyOwner {
        contractStartAt = _time;
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

    function depositNFTsToPlay(address _nft, uint256[] memory _tokenIds)
        external
    {
        DepositedNFT storage _user = nftUserInfo[_nft][msg.sender];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            IERC721Upgradeable(_nft).transferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
            _user.depositedTokenIds.push(_tokenIds[i]);
            _user.tokenIdToIndex[_tokenIds[i]] = _user.depositedTokenIds.length;
        }

        userInfo[msg.sender].lastUpdatedAt = block.timestamp;

        emit NFTDeposit(_nft, msg.sender, abi.encodePacked(_tokenIds));
    }

    function withdrawNFTs(
        address _nft,
        uint256[] memory _tokenIds,
        uint256 _expiredTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(block.timestamp < _expiredTime, "withdrawNFTs: !expired");
        bytes32 msgHash = keccak256(
            abi.encode(_nft, msg.sender, _tokenIds, _expiredTime)
        );
        require(
            operator == recoverSigner(r, s, v, msgHash),
            "invalid operator"
        );
        DepositedNFT storage _user = nftUserInfo[_nft][msg.sender];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(_user.tokenIdToIndex[_tokenIds[i]] > 0, "invalid tokenId");
            IERC721Upgradeable(_nft).transferFrom(
                address(this),
                msg.sender,
                _tokenIds[i]
            );
            //swap
            uint256 _index = _user.tokenIdToIndex[_tokenIds[i]] - 1;
            _user.depositedTokenIds[_index] = _user.depositedTokenIds[
                _user.depositedTokenIds.length - 1
            ];
            _user.tokenIdToIndex[_user.depositedTokenIds[_index]] = _index + 1;
            _user.depositedTokenIds.pop();

            delete _user.tokenIdToIndex[_tokenIds[i]];
        }

        userInfo[msg.sender].lastUpdatedAt = block.timestamp;
        emit NFTWithdraw(_nft, msg.sender, abi.encodePacked(_tokenIds));
    }

    function withdrawTokens(
        uint256 _hplSpent,
        uint256 _hplWithdrawAmount,
        uint256 _hpwSpent,
        uint256 _hpwWithdrawAmount,
        uint256 _expiredTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(block.timestamp < _expiredTime, "withdrawTokens: !expired");
        bytes32 msgHash = keccak256(
            abi.encode(
                msg.sender,
                _hplSpent,
                _hplWithdrawAmount,
                _hpwSpent,
                _hpwWithdrawAmount,
                _expiredTime
            )
        );
        require(
            operator == recoverSigner(r, s, v, msgHash),
            "invalid operator"
        );
        UserInfo storage _user = userInfo[msg.sender];
        UserInfoTokenWithdraw
            storage _userInfoTokenWithdraw = userInfoTokenWithdraw[msg.sender];
        require(
            _user.hplDeposit >=
                _hplSpent +
                    _hplWithdrawAmount +
                    _userInfoTokenWithdraw.hplWithdraw,
            "invalid hplSpent"
        );
        require(
            _user.hpwDeposit >=
                _hpwSpent +
                    _hpwWithdrawAmount +
                    _userInfoTokenWithdraw.hpwWithdraw,
            "invalid hpwSpent"
        );

        //return hpl
        hpl.safeTransfer(msg.sender, _hplWithdrawAmount);

        //return hpw
        hpw.safeTransfer(msg.sender, _hpwWithdrawAmount);

        //burn hplSpent and hpwSpent
        // IBurn(address(hpl)).burn(_hplSpent);
        // IBurn(address(hpw)).burn(_hpwSpent);

        emit TokenWithdraw(msg.sender, _hplWithdrawAmount, _hpwWithdrawAmount);

        _userInfoTokenWithdraw.hplWithdraw += _hplWithdrawAmount;
        _userInfoTokenWithdraw.hpwWithdraw += _hpwWithdrawAmount;

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
        uint256 lastUpdatedAt = _user.lastUpdatedAt;
        uint256 _lastRewardClaimedAt = _user.lastRewardClaimedAt > 0
            ? _user.lastRewardClaimedAt
            : lastUpdatedAt;
        _lastRewardClaimedAt = _lastRewardClaimedAt > 0
            ? _lastRewardClaimedAt
            : contractStartAt;
        require(
            _lastRewardClaimedAt + minTimeBetweenClaims < block.timestamp,
            "!minTimeBetweenClaims"
        );
        require(_user.hplRewardClaimed <= _hplRewards, "invalid _hplRewards");
        require(_user.hpwRewardClaimed <= _hpwRewards, "invalid _hpwRewards");

        uint256 toTransferHpl = _hplRewards - _user.hplRewardClaimed;
        uint256 toTransferHpw = _hpwRewards - _user.hpwRewardClaimed;
        address _land = 0x9c271b95A2Aa7Ab600b9B2E178CbBec2A6dc1bAb;
        uint256 depositedLandCount = getLandDepositedCount(msg.sender, _land);
        uint256 maxWithdrawal = 3000e18 * depositedLandCount;
        if (toTransferHpw > maxWithdrawal) {
            toTransferHpw = maxWithdrawal;
            if (toTransferHpw > 10000e18) {
                toTransferHpw = 10000e18;
            }
            _hpwRewards = _user.hpwRewardClaimed + toTransferHpw;
        }
        _user.hplRewardClaimed = _hplRewards;
        _user.hpwRewardClaimed = _hpwRewards;
        _user.lastRewardClaimedAt = block.timestamp;

        hpl.safeTransfer(msg.sender, toTransferHpl);
        //mint hpw rewards
        IMint(address(hpw)).mint(msg.sender, toTransferHpw);

        emit RewardsClaimed(msg.sender, toTransferHpl, toTransferHpw);
    }

    function getUserInfo(address _user)
        external
        view
        returns (
            uint256 hplDeposit,
            uint256 hpwDeposit,
            uint256 lastUpdatedAt,
            uint256 hplRewardClaimed,
            uint256 hpwRewardClaimed
        )
    {
        UserInfo storage _userInfo = userInfo[_user];
        return (
            _userInfo.hplDeposit,
            _userInfo.hpwDeposit,
            _userInfo.lastUpdatedAt,
            _userInfo.hplRewardClaimed,
            _userInfo.hpwRewardClaimed
        );
    }

    function getUserInfo2(address _user)
        external
        view
        returns (
            uint256 hplDeposit,
            uint256 hpwDeposit,
            uint256 lastUpdatedAt,
            uint256 hplRewardClaimed,
            uint256 hpwRewardClaimed,
            uint256 lastRewardClaimedAt
        )
    {
        UserInfo storage _userInfo = userInfo[_user];
        return (
            _userInfo.hplDeposit,
            _userInfo.hpwDeposit,
            _userInfo.lastUpdatedAt,
            _userInfo.hplRewardClaimed,
            _userInfo.hpwRewardClaimed,
            _userInfo.lastRewardClaimedAt
        );
    }

    function getDepositedNFTs(address _nft, address _user)
        external
        view
        returns (uint256[] memory depositedLands)
    {
        return nftUserInfo[_nft][_user].depositedTokenIds;
    }

    function getDepositedNFTs2(address _nft, address _user)
        external
        view
        returns (uint256[] memory depositedLands)
    {
        return nftUserInfo[_nft][_user].depositedTokenIds;
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

    function getLandDepositedCount(address _addr, address _nft)
        public
        view
        returns (uint256)
    {
        return nftUserInfo[_nft][_addr].depositedTokenIds.length;
    }
}
