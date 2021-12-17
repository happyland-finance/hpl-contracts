pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../lib/Upgradeable.sol";

contract Market is Upgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address payable;

    address public constant NATIVE_TOKEN =
        0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;

    address[] public supportedPaymentTokenList;
    mapping(address => bool) public supportedPaymentMapping;
    uint256 public feePercentX10; //default 1%
    address payable public feeReceiver;

    struct SaleInfo {
        bool isSold;
        bool isActive; //false mint already cancelled
        address payable owner;
        uint256 lastUpdated;
        uint256 tokenId;
        uint256 price;
        uint256 saleId;
        address paymentToken;
        address whitelistedBuyer;
        address nft;
    }
    address[] public supportedNFTList;
    mapping(address => bool) public supportedNFTMapping;

    SaleInfo[] public saleList;

    event NFTSupported(address nft, bool val);

    event NewTokenSale(
        address owner,
        address nft,
        uint256 updatedAt,
        uint256 tokenId,
        uint256 price,
        uint256 saleId,
        address paymentToken,
        address whitelistedBuyer
    );
    event TokenSaleUpdated(
        address owner,
        address nft,
        uint256 updatedAt,
        uint256 tokenId,
        uint256 price,
        uint256 saleId,
        address whitelistedBuyer
    );
    event SaleCancelled(
        address owner,
        address nft,
        uint256 updatedAt,
        uint256 tokenId,
        uint256 price,
        uint256 saleId
    );
    event TokenPurchase(
        address owner,
        address buyer,
        address nft,
        uint256 updatedAt,
        uint256 tokenId,
        uint256 price,
        uint256 saleId,
        address paymentToken
    );

    modifier onlySaleOwner(uint256 _saleId) {
        require(msg.sender == saleList[_saleId].owner, "Invalid sale owner");
        _;
    }

    modifier onlySupportedPaymentToken(address _token) {
        require(supportedPaymentMapping[_token], "unsupported payment token");
        _;
    }

    modifier onlySupportedNFT(address _nft) {
        require(supportedNFTMapping[_nft], "not supported nft");
        _;
    }

    function setSupportedNFTs(address[] memory _nfts) external onlyOwner {
        _setSupportedNFTs(_nfts);
    }

    function _setSupportedNFTs(address[] memory _nfts) private {
        //diminish the current list
        for (uint256 i = 0; i < supportedNFTList.length; i++) {
            supportedNFTMapping[supportedNFTList[i]] = false;
            emit NFTSupported(supportedNFTList[i], false);
        }
        supportedNFTList = _nfts;
        for (uint256 i = 0; i < supportedNFTList.length; i++) {
            supportedNFTMapping[supportedNFTList[i]] = true;
            emit NFTSupported(_nfts[i], true);
        }
    }

    function initialize(
        address _land,
        address[] memory _supportedPaymentTokens,
        address payable _feeReceiver
    ) external initializer {
        initOwner();
        address[] memory _lands = new address[](1);
        _lands[0] = _land;
        _setSupportedNFTs(_lands);
        _changePaymentList(_supportedPaymentTokens);
        feeReceiver = _feeReceiver;
        feePercentX10 = 40;
    }

    function changeFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 100, "changeFee: new fee too high"); //max 10%
        feePercentX10 = _newFee;
    }

    function changeFeeReceiver(address payable _newFeeReceiver)
        external
        onlyOwner
    {
        require(
            _newFeeReceiver != payable(0),
            "changeFeeReceiver: null address"
        );
        feeReceiver = _newFeeReceiver;
    }

    function changePaymentList(address[] memory _supportedPaymentTokens)
        external
        onlyOwner
    {
        _changePaymentList(_supportedPaymentTokens);
    }

    function _changePaymentList(address[] memory _supportedPaymentTokens)
        private
    {
        //reset current list
        for (uint256 i = 0; i < supportedPaymentTokenList.length; i++) {
            supportedPaymentMapping[supportedPaymentTokenList[i]] = false;
        }
        supportedPaymentTokenList = _supportedPaymentTokens;
        for (uint256 i = 0; i < supportedPaymentTokenList.length; i++) {
            supportedPaymentMapping[supportedPaymentTokenList[i]] = true;
        }
    }

    function isNative(address _token) public pure returns (bool) {
        return _token == NATIVE_TOKEN;
    }

    function setTokenSale(
        address _nft,
        uint256 _tokenId,
        address _paymentToken,
        uint256 _price,
        address _whitelistedBuyer
    ) external onlySupportedNFT(_nft) onlySupportedPaymentToken(_paymentToken) {
        require(_price > 0, "price must not be 0");
        //transfer token from sender to contract
        IERC721Upgradeable(_nft).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        saleList.push(
            SaleInfo(
                false,
                true,
                payable(msg.sender),
                block.timestamp,
                _tokenId,
                _price,
                saleList.length,
                _paymentToken,
                _whitelistedBuyer,
                _nft
            )
        );

        emit NewTokenSale(
            msg.sender,
            _nft,
            block.timestamp,
            _tokenId,
            _price,
            saleList.length - 1,
            _paymentToken,
            _whitelistedBuyer
        );
    }

    function updateSaleInfo(
        address _nft,
        uint256 _saleId,
        uint256 _newPrice,
        address _whitelistedBuyer
    ) external onlySaleOwner(_saleId) {
        require(_newPrice > 0, "price must not be 0");
        SaleInfo storage sale = saleList[_saleId];
        require(
            sale.isActive && !sale.isSold,
            "updateSaleInfo: sale inactive or already sold"
        );
        sale.price = _newPrice;
        sale.lastUpdated = block.timestamp;
        sale.whitelistedBuyer = _whitelistedBuyer;

        emit TokenSaleUpdated(
            msg.sender,
            _nft,
            block.timestamp,
            sale.tokenId,
            _newPrice,
            _saleId,
            _whitelistedBuyer
        );
    }

    function cancelTokenSale(address _nft, uint256 _saleId)
        external
        onlySaleOwner(_saleId)
    {
        SaleInfo storage sale = saleList[_saleId];
        require(
            sale.isActive && !sale.isSold,
            "cancelTokenSale: sale inactive or already sold"
        );
        require(sale.nft == _nft, "cancelTokenSale: invalid nft address");
        sale.isActive = false;
        IERC721Upgradeable(_nft).transferFrom(
            address(this),
            msg.sender,
            sale.tokenId
        );

        sale.lastUpdated = block.timestamp;

        emit SaleCancelled(
            msg.sender,
            _nft,
            block.timestamp,
            sale.tokenId,
            sale.price,
            _saleId
        );
    }

    function buyNFT(uint256 _saleId) external payable {
        SaleInfo storage sale = saleList[_saleId];
        require(
            sale.isActive && !sale.isSold,
            "cancelTokenSale: sale inactive or already sold"
        );

        if (sale.whitelistedBuyer != address(0)) {
            require(
                sale.whitelistedBuyer == msg.sender,
                "buyToken: invalid whitelisted address to buy"
            );
        }

        sale.isSold = true;
        sale.isActive = false;

        uint256 price = sale.price;
        //transfer fee
        if (isNative(sale.paymentToken)) {
            require(msg.value >= price, "insufficiant payment value");
            sale.owner.sendValue(price.mul(1000 - feePercentX10).div(1000));
            feeReceiver.sendValue(address(this).balance);
        } else {
            IERC20Upgradeable(sale.paymentToken).safeTransferFrom(
                msg.sender,
                feeReceiver,
                price.mul(feePercentX10).div(1000)
            );
            //transfer to seller
            IERC20Upgradeable(sale.paymentToken).safeTransferFrom(
                msg.sender,
                sale.owner,
                price.mul(1000 - feePercentX10).div(1000)
            );
        }

        sale.lastUpdated = block.timestamp;
        IERC721Upgradeable(sale.nft).transferFrom(
            address(this),
            msg.sender,
            sale.tokenId
        );

        emit TokenPurchase(
            sale.owner,
            msg.sender,
            sale.nft,
            block.timestamp,
            sale.tokenId,
            sale.price,
            _saleId,
            sale.paymentToken
        );
    }

    function getAllSales() external view returns (SaleInfo[] memory _lands) {
        return (saleList);
    }

    function getSaleCounts() external view returns (uint256 _landCount) {
        return saleList.length;
    }

    function getSaleInfo(uint256 _saleId)
        external
        view
        returns (SaleInfo memory sale)
    {
        return saleList[_saleId];
    }
}
