pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../lib/Upgradeable.sol";
import "../interfaces/ILand.sol";
import "../lib/SignerRecover.sol";
import "../lib/BlackholePreventionUpgradeable.sol";

contract LandSale is
    Upgradeable,
    BlackholePreventionUpgradeable,
    SignerRecover
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    ILand public land;
    mapping(address => bool) public acceptToken;
    address public constant nativeToken =
        0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
    address public operator;
    uint256 public maxLandId;
    uint256 public maxBoxNumber;
    uint256 public currentBoxNumber;

    event BuyBox(
        address buyer,
        address tokenPayment,
        uint256 tokenAmount,
        uint256 boxNumber
    );
    event BuyBoxMultiToken(
        address buyer,
        bytes tokenPayment,
        bytes tokenAmount,
        uint256 boxNumber
    );
    event OpenBox(address buyer, uint256 tokenId, bytes32 commitment);

    struct BuyerLastToken {
        uint256 tokenId;
        bytes32 commitment;
    }
    mapping(address => uint256) public buyerBoxNumber;
    mapping(address => uint256) public buyerBoxOpen;
    mapping(bytes32 => bool) public useKeys;
    mapping(address => uint256) public buyerMaxBoxNumber;
    mapping(address => BuyerLastToken) public buyerLastTokenId;

    function initialize(ILand _land) external initializer {
        initOwner();

        land = _land;
        maxLandId = 1;
    }

    function setLandAddress(ILand _land) public onlyOwner {
        land = _land;
    }

    function setMaxLandId(uint256 max) public onlyOwner {
        maxLandId = max;
    }

    function setMaxBoxNumber(uint256 max) public onlyOwner {
        maxBoxNumber = max;
    }

    function updateTokenAccept(address _token, bool _value) public onlyOwner {
        acceptToken[_token] = _value;
    }

    function updateMultiTokenAccept(address[] memory _tokens, bool _value) public onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            acceptToken[_tokens[i]] = _value;
        }
    }

    function setOperator(address _operator) public onlyOwner {
        operator = _operator;
    }

    function buyBox(
        address _tokenPayment,
        uint256 _tokenAmount,
        uint256 _boxNumber,
        uint256 _maxBoxNumber,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external payable {
        bytes32 msgHash = keccak256(
            abi.encode(
                msg.sender,
                _tokenPayment,
                _tokenAmount,
                _boxNumber,
                _maxBoxNumber,
                _expiryTime
            )
        );
        require(
            operator == recoverSigner(r, s, v, msgHash),
            "invalid operator"
        );
        require(maxBoxNumber >= currentBoxNumber, "reached the limit");
        require(maxBoxNumber >= currentBoxNumber + _boxNumber, "boxNumber too much");
        require(buyerBoxNumber[msg.sender] + _boxNumber <= _maxBoxNumber, "invalid boxNumber");
        currentBoxNumber = currentBoxNumber + _boxNumber;
        uint256 amount = _tokenAmount * _boxNumber;
        if (_tokenPayment == nativeToken) {
            require(msg.value == amount, "Not enough BNB");
        } else {
            IERC20Upgradeable(_tokenPayment).safeTransferFrom(msg.sender, address(this), amount);
        }

        buyerMaxBoxNumber[msg.sender] = _maxBoxNumber;
        buyerBoxNumber[msg.sender] = buyerBoxNumber[msg.sender] + _boxNumber;
        emit BuyBox(msg.sender, _tokenPayment, _tokenAmount, _boxNumber);
    }

    function addBoxByOwner(
        address[] memory _buyers,
        uint256[] memory _boxNumbers
    ) external onlyOwner {
        require(_buyers.length == _boxNumbers.length, "invalid length");

        for (uint256 i = 0; i < _buyers.length; i++) {
            buyerMaxBoxNumber[_buyers[i]] += _boxNumbers[i];
            buyerBoxNumber[_buyers[i]] += _boxNumbers[i];
            emit BuyBox(_buyers[i], address(0), 0, _boxNumbers[i]);
        }
    }

    function buyBoxMultiToken(
        address[] memory _tokenPayment,
        uint256[] memory _tokenAmount,
        uint256 _boxNumber,
        uint256 _maxBoxNumber,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external payable {
        require(_tokenPayment.length == _tokenAmount.length, "invalid length");
        bytes32 msgHash = keccak256(
            abi.encode(
                msg.sender,
                _tokenPayment,
                _tokenAmount,
                _boxNumber,
                _maxBoxNumber,
                _expiryTime
            )
        );
        require(
            operator == recoverSigner(r, s, v, msgHash),
            "invalid operator"
        );
        require(maxBoxNumber > currentBoxNumber, "reached the limit");
        require(buyerBoxNumber[msg.sender] + _boxNumber <= _maxBoxNumber, "invalid boxNumber");
        currentBoxNumber = currentBoxNumber + _boxNumber;
        for (uint256 i = 0; i < _tokenPayment.length; i++) {
            uint256 amount = _tokenAmount[i] * _boxNumber;
            if (_tokenPayment[i] == nativeToken) {
                require(msg.value == amount, "Not enough BNB");
            } else {
                IERC20Upgradeable(_tokenPayment[i]).safeTransferFrom(msg.sender, address(this), amount);
            }
        }

        buyerMaxBoxNumber[msg.sender] = _maxBoxNumber;
        buyerBoxNumber[msg.sender] = buyerBoxNumber[msg.sender] + _boxNumber;
        emit BuyBoxMultiToken(
            msg.sender,
            abi.encodePacked(_tokenPayment),
            abi.encodePacked(_tokenAmount),
            _boxNumber
        );
    }

    function countNotOpenBox(address buyer) public view returns (uint256) {
        return buyerBoxNumber[buyer] - buyerBoxOpen[buyer];
    }

    function openBox(
        bytes32 _key,
        bytes32 _commitment,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(
            buyerBoxOpen[msg.sender] < buyerBoxNumber[msg.sender],
            "Dont have any box"
        );
        require(!useKeys[_key], "!!invalid key");
        useKeys[_key] = true;

        bytes32 msgHash = keccak256(
            abi.encode(msg.sender, _key, _commitment, _expiryTime)
        );
        require(
            operator == recoverSigner(r, s, v, msgHash),
            "invalid operator"
        );

        buyerBoxOpen[msg.sender] = buyerBoxOpen[msg.sender] + 1;
        land.mint(msg.sender, maxLandId);

        buyerLastTokenId[msg.sender].tokenId = maxLandId;
        buyerLastTokenId[msg.sender].commitment = _commitment;
        emit OpenBox(msg.sender, maxLandId, _commitment);
        maxLandId = maxLandId + 1;
    }

    function claimLandFromOther(
        bytes32 _key,
        bytes32 _commitment,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        bytes32 msgHash = keccak256(
            abi.encode(msg.sender, _key, _commitment, _expiryTime)
        );
        require(
            operator == recoverSigner(r, s, v, msgHash),
            "invalid operator"
        );
        require(!useKeys[_key], "invalid key");
        useKeys[_key] = true;

        land.mint(msg.sender, maxLandId);

        buyerLastTokenId[msg.sender].tokenId = maxLandId;
        buyerLastTokenId[msg.sender].commitment = _commitment;
        emit OpenBox(msg.sender, maxLandId, _commitment);
        maxLandId = maxLandId + 1;
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
