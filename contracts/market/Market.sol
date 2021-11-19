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

    IERC721Upgradeable public land;
    IERC721Upgradeable public house;
    address[] public supportedPaymentTokenList;
    uint256 public feePercentX10 = 10; //default 1%
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
    }

    SaleInfo[] public landSaleList;
    SaleInfo[] public houseSaleList;

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
        uint256 saleId
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

    modifier onlySaleOwner(bool _isLand, uint256 _saleId) {
        if (_isLand) {
            require(
                msg.sender == landSaleList[_saleId].owner,
                "Invalid land sale owner"
            );
        } else {
            require(
                msg.sender == houseSaleList[_saleId].owner,
                "Invalid house sale owner"
            );
        }
        _;
    }

    modifier onlySupportedPaymentToken(address _token) {
        bool found = false;
        for (uint256 i = 0; i < supportedPaymentTokenList.length; i++) {
            if (supportedPaymentTokenList[i] == _token) {
                found = true;
                break;
            }
        }
        require(found, "unsupported payment token");
        _;
    }

    function initialize(
        address _land,
        address _house,
        address[] memory _supportedPaymentTokens,
        address payable _feeReceiver
    ) external initializer {
        initOwner();
        land = IERC721Upgradeable(_land);
        house = IERC721Upgradeable(_house);
        supportedPaymentTokenList = _supportedPaymentTokens;
        feeReceiver = _feeReceiver;
    }

    function changeFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 100, "changeFee: new fee too high"); //max 10%
        feePercentX10 = _newFee;
    }

    function changeFeeReceiver(address payable _newFeeReceiver) external onlyOwner {
        require(
            _newFeeReceiver != payable(0),
            "changeFeeReceiver: null address"
        ); //max 10%
        feeReceiver = _newFeeReceiver;
    }

    function changePaymentList(address[] memory _supportedPaymentTokens)
        external
        onlyOwner
    {
        supportedPaymentTokenList = _supportedPaymentTokens;
    }

    function isNative(address _token) public pure returns (bool) {
        return _token == NATIVE_TOKEN;
    }

    function setTokenSale(
        bool _isLand,
        uint256 _tokenId,
        address _paymentToken,
        uint256 _price,
        address _whitelistedBuyer
    ) external onlySupportedPaymentToken(_paymentToken) {
        require(_price > 0, "price must not be 0");
        //transfer token from sender to contract
        if (_isLand) {
            land.transferFrom(msg.sender, address(this), _tokenId);
        } else {
            house.transferFrom(msg.sender, address(this), _tokenId);
        }
        //create a sale
        if (_isLand) {
            landSaleList.push(
                SaleInfo(
                    false,
                    true,
                    payable(msg.sender),
                    block.timestamp,
                    _tokenId,
                    _price,
                    landSaleList.length,
                    _paymentToken,
                    _whitelistedBuyer
                )
            );
        } else {
            houseSaleList.push(
                SaleInfo(
                    false,
                    true,
                    payable(msg.sender),
                    block.timestamp,
                    _tokenId,
                    _price,
                    houseSaleList.length,
                    _paymentToken,
                    _whitelistedBuyer
                )
            );
        }

        emit NewTokenSale(
            msg.sender,
            _isLand ? address(land) : address(house),
            block.timestamp,
            _tokenId,
            _price,
            _isLand ? landSaleList.length - 1 : houseSaleList.length - 1,
            _paymentToken,
            _whitelistedBuyer
        );
    }

    function changeTokenSalePrice(
        bool _isLand,
        uint256 _saleId,
        uint256 _newPrice
    ) external onlySaleOwner(_isLand, _saleId) {
        require(_newPrice > 0, "price must not be 0");
        SaleInfo storage sale = _isLand
            ? landSaleList[_saleId]
            : houseSaleList[_saleId];
        require(
            sale.isActive && !sale.isSold,
            "changeTokenSalePrice: sale inactive or already sold"
        );
        sale.price = _newPrice;
        sale.lastUpdated = block.timestamp;

        emit TokenSaleUpdated(
            msg.sender,
            _isLand ? address(land) : address(house),
            block.timestamp,
            sale.tokenId,
            _newPrice,
            _saleId
        );
    }

    function cancelTokenSale(bool _isLand, uint256 _saleId)
        external
        onlySaleOwner(_isLand, _saleId)
    {
        SaleInfo storage sale = _isLand
            ? landSaleList[_saleId]
            : houseSaleList[_saleId];
        require(
            sale.isActive && !sale.isSold,
            "cancelTokenSale: sale inactive or already sold"
        );
        sale.isActive = false;
        if (_isLand) {
            land.transferFrom(address(this), msg.sender, sale.tokenId);
        } else {
            house.transferFrom(address(this), msg.sender, sale.tokenId);
        }
        sale.lastUpdated = block.timestamp;

        emit SaleCancelled(
            msg.sender,
            _isLand ? address(land) : address(house),
            block.timestamp,
            sale.tokenId,
            sale.price,
            _saleId
        );
    }

    function buyToken(bool _isLand, uint256 _saleId) external payable {
        SaleInfo storage sale = _isLand
            ? landSaleList[_saleId]
            : houseSaleList[_saleId];
        require(
            sale.isActive && !sale.isSold,
            "cancelTokenSale: sale inactive or already sold"
        );

        if (sale.whitelistedBuyer != address(0)) {
            require(sale.whitelistedBuyer == msg.sender, "buyToken: invalid whitelisted address to buy");
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
        if (_isLand) {
            land.transferFrom(address(this), msg.sender, sale.tokenId);
        } else {
            house.transferFrom(address(this), msg.sender, sale.tokenId);
        }

        emit TokenPurchase(
            sale.owner,
            msg.sender,
            _isLand ? address(land) : address(house),
            block.timestamp,
            sale.tokenId,
            sale.price,
            _saleId,
            sale.paymentToken
        );
    }

    function getAllSales()
        external
        view
        returns (SaleInfo[] memory _lands, SaleInfo[] memory _houses)
    {
        return (landSaleList, houseSaleList);
    }

    function getSaleCounts()
        external
        view
        returns (uint256 _landCount, uint256 _houseCount)
    {
        return (landSaleList.length, houseSaleList.length);
    }

    function getSaleInfo(bool _isLand, uint256 _index)
        external
        view
        returns (SaleInfo memory list)
    {
        return _isLand ? landSaleList[_index] : houseSaleList[_index];
    }
}
