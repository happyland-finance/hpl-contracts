pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "../interfaces/ILand.sol";
import "../lib/BlackholePrevention.sol";
import "../lib/Upgradeable.sol";

contract Land is
    Upgradeable,
    ERC721EnumerableUpgradeable,
    ILand,
    BlackholePrevention
{
    using SafeMathUpgradeable for uint256;
    using StringsUpgradeable for uint256;

    uint256 public currentId;

    string public baseURI;
    mapping(uint256 => string) public tokenURIs;

    mapping(address => uint256) public latestTokenMinted;
    mapping(uint256 => uint256) public tokenRarityMapping;
    address public factory;

    function initialize(address _nftFactory) external initializer {
        initOwner();
        __ERC721_init("HappyLand Land NFT", "HLandNFT");
        currentId = 0;
        factory = _nftFactory;
    }

    function setBaseURI(string memory _b) external onlyOwner {
        baseURI = _b;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI)
        external
        onlyOwner
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI set of nonexistent token"
        );
        tokenURIs[tokenId] = _tokenURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory _tokenURI = tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can do this");
        _;
    }

    //client compute result index off-chain, the function will verify it
    function mint(address _recipient, uint256 _rarity)
        external
        override
        onlyFactory
        returns (uint256 _tokenId)
    {
        currentId = currentId.add(1);
        uint256 tokenId = currentId;
        require(tokenRarityMapping[tokenId] == 0, "Token already exists");

        _mint(_recipient, tokenId);
        tokenRarityMapping[tokenId] = _rarity;
        latestTokenMinted[_recipient] = tokenId;
        return tokenId;
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
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
