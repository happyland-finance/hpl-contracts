pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../interfaces/ILand.sol";
import "../lib/BlackholePreventionUpgradeable.sol";
import "../lib/Upgradeable.sol";
import "../lib/SignerRecover.sol";

contract NFTSale is
    Upgradeable,
    PausableUpgradeable,
    BlackholePreventionUpgradeable,
    SignerRecover
{
    using AddressUpgradeable for address payable;
    using SafeMathUpgradeable for uint256;

    ILand public land;
    address payable public feeTo;
    address public operator;

    //rarity => price
    mapping(bytes32 => bool) public claimIds;
    event ClaimLand(
        address user,
        uint256 _tokenId,
        uint256 _rarity,
        uint256 _claimFee
    );

    function initialize(
        address _land,
        address payable _feeTo,
        address _operator
    ) external initializer {
        initOwner();

        land = ILand(_land);
        feeTo = _feeTo;

        operator = _operator;
    }

    function setFeeTo(address payable _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    function setPause(bool _val) external onlyOwner {
        if (_val) {
            _pause();
        } else {
            _unpause();
        }
    }

    function claimLand(
        bytes32 _claimId,
        uint256 _tokenId,
        uint256 _rarity,
        uint256 _claimFee,
        uint256 _deadline,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external payable {
        require(!claimIds[_claimId], "already claim");
        claimIds[_claimId] = true;
        require(_deadline >= block.timestamp, "deadline");

        require(msg.value >= _claimFee, "insufficient claim fee");

        bytes32 message = keccak256(
            abi.encode(
                "claimLand",
                msg.sender,
                _claimId,
                _tokenId,
                _rarity,
                _claimFee,
                _deadline
            )
        );

        require(
            operator == recoverSigner(r, s, v, message),
            "Invalid operator"
        );

        transferToFeeTo();

        land.mint(msg.sender, _tokenId);

        emit ClaimLand(msg.sender, _tokenId, _rarity, _claimFee);
    }

    function transferToFeeTo() internal {
        if (address(this).balance > 0) {
            feeTo.sendValue(address(this).balance);
        }
    }

    function withdrawEther(address payable receiver, uint256 amount)
        external
        virtual
        onlyOwner
    {
        _withdrawEther(receiver, amount);
    }

    function withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external virtual onlyOwner {
        _withdrawERC20(receiver, tokenAddress, amount);
    }

    function withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId
    ) external virtual onlyOwner {
        _withdrawERC721(receiver, tokenAddress, tokenId);
    }
}
