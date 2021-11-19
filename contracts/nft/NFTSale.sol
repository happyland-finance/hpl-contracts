pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../interfaces/IHouse.sol";
import "../interfaces/ILand.sol";
import "../lib/BlackholePrevention.sol";
import "../lib/Upgradeable.sol";

contract NFTSale is
    Upgradeable,
    PausableUpgradeable,
    ERC721EnumerableUpgradeable,
    BlackholePrevention
{
    using AddressUpgradeable for address payable;
    using SafeMathUpgradeable for uint256;

    ILand public land;
    IHouse public house;
    address payable public feeTo;

    //rarity => price
    mapping(uint256 => uint256) public landPriceMap;
    mapping(uint256 => uint256) public housePriceMap;

    struct CurrentSale {
        uint256 startTime;
        uint256 endTime;
        uint256[] landCountRarities;
        uint256[] landCountForSales; //corresponding rarity
        mapping(uint256 => uint256) landRarityMap; //mapping from rarity to index + 1 in array landCountRarities
        uint256[] currentLandCounts;
        uint256[] houseCountRarities;
        uint256[] houseCountForSales; //corresponding rarity
        mapping(uint256 => uint256) houseRarityMap; //mapping from rarity to index + 1 in array houseCountRarities
        uint256[] currentHouseCounts;
    }
    CurrentSale public currentSale;

    event SetHousePrice(uint256 _price, uint256 _rarity, address _setter);
    event SetLandPrice(uint256 _price, uint256 _rarity, address _setter);

    modifier canBuyLand(uint256 _rarity) {
        require(
            currentSale.startTime <= block.timestamp &&
                block.timestamp <= currentSale.endTime,
            "Time expired"
        );
        uint256 rarityIndex = currentSale.landRarityMap[_rarity];
        require(
            rarityIndex > 0 &&
                rarityIndex <= currentSale.landCountRarities.length,
            "invalid rarity"
        );
        require(
            currentSale.landCountForSales[rarityIndex - 1] >
                currentSale.currentLandCounts[rarityIndex - 1],
            "land sold out"
        );
        _;
    }

    modifier canBuyHouse(uint256 _rarity) {
        require(
            currentSale.startTime <= block.timestamp &&
                block.timestamp <= currentSale.endTime,
            "Time expired"
        );
        uint256 rarityIndex = currentSale.houseRarityMap[_rarity];
        require(
            rarityIndex > 0 &&
                rarityIndex <= currentSale.houseCountRarities.length,
            "invalid rarity"
        );
        require(
            currentSale.houseCountForSales[rarityIndex - 1] >
                currentSale.currentHouseCounts[rarityIndex - 1],
            "house sold out"
        );
        _;
    }

    function initialize(
        address _house,
        address _land,
        uint256[] memory _supportedHouseRarities,
        uint256[] memory _housePricesForRarities,
        uint256[] memory _supportedLandRarities,
        uint256[] memory _landPricesForRarities,
        address payable _feeTo
    ) external initializer {
        initOwner();

        house = IHouse(_house);
        land = ILand(_land);
        feeTo = _feeTo;

        setHousePrice(_supportedHouseRarities, _housePricesForRarities);
        setLandPrice(_supportedLandRarities, _landPricesForRarities);
    }

    function setLandPrice(
        uint256[] memory _supportedRarities,
        uint256[] memory _landPricesForRarities
    ) public onlyOwner {
        require(
            _supportedRarities.length == _landPricesForRarities.length,
            "setLandPrice: Invalid input parameter length"
        );
        for (uint256 i = 0; i < _supportedRarities.length; i++) {
            landPriceMap[_supportedRarities[i]] = _landPricesForRarities[i];
            emit SetLandPrice(
                _landPricesForRarities[i],
                _supportedRarities[i],
                msg.sender
            );
        }
    }

    function setHousePrice(
        uint256[] memory _supportedRarities,
        uint256[] memory _housePricesForRarities
    ) public onlyOwner {
        require(
            _supportedRarities.length == _housePricesForRarities.length,
            "setHousePrice: Invalid input parameter length"
        );
        for (uint256 i = 0; i < _supportedRarities.length; i++) {
            housePriceMap[_supportedRarities[i]] = _housePricesForRarities[i];
            emit SetHousePrice(
                _housePricesForRarities[i],
                _supportedRarities[i],
                msg.sender
            );
        }
    }

    function setFeeTo(address payable _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function setPause(bool _val) external onlyOwner {
        if (_val) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setNewSale(
        uint256 _startTime,
        uint256 _duration,
        uint256[] memory _landCountRarities,
        uint256[] memory _landCountForSales,
        uint256[] memory _houseCountRarities,
        uint256[] memory _houseCountForSales
    ) external onlyOwner {
        require(
            _landCountRarities.length == _landCountForSales.length,
            "setNewSale: land Invalid input length"
        );
        require(
            _houseCountRarities.length == _houseCountForSales.length,
            "setNewSale: house Invalid input length"
        );
        currentSale.startTime = _startTime > block.timestamp
            ? _startTime
            : block.timestamp;
        currentSale.endTime = currentSale.startTime.add(_duration);

        currentSale.landCountRarities = _landCountRarities;
        currentSale.landCountForSales = _landCountForSales;
        for (uint256 i = 0; i < _landCountRarities.length; i++) {
            currentSale.landRarityMap[_landCountRarities[i]] = i + 1; // + 1 to avoid 0 by default
        }
        currentSale.currentLandCounts = new uint256[](
            _landCountRarities.length
        );

        currentSale.houseCountRarities = _houseCountRarities;
        currentSale.houseCountForSales = _houseCountForSales;
        for (uint256 i = 0; i < _houseCountRarities.length; i++) {
            currentSale.houseRarityMap[_houseCountRarities[i]] = i + 1; // + 1 to avoid 0 by default
        }
        currentSale.currentHouseCounts = new uint256[](
            _houseCountRarities.length
        );
    }

    function updateCurrentSale(
        uint256 _startTime,
        uint256 _duration,
        uint256[] memory _landCountRarities,
        uint256[] memory _landCountForSales,
        uint256[] memory _houseCountRarities,
        uint256[] memory _houseCountForSales
    ) external onlyOwner {
        currentSale.startTime = _startTime;
        currentSale.endTime = currentSale.startTime.add(_duration);

        currentSale.landCountRarities = _landCountRarities;
        currentSale.landCountForSales = _landCountForSales;
        for (uint256 i = 0; i < _landCountRarities.length; i++) {
            currentSale.landRarityMap[_landCountRarities[i]] = i;
        }

        currentSale.houseCountRarities = _houseCountRarities;
        currentSale.houseCountForSales = _houseCountForSales;
        for (uint256 i = 0; i < _houseCountRarities.length; i++) {
            currentSale.houseRarityMap[_houseCountRarities[i]] = i + 1; // + 1 to avoid 0 by default
        }
    }

    function buyLand(uint256 _rarity)
        public
        payable
        whenNotPaused
        canBuyLand(_rarity)
    {
        require(landPriceMap[_rarity] != 0, "Unsupported rarity");
        require(
            msg.value >= landPriceMap[_rarity],
            "buyLand:: Payment not enough"
        );

        land.mint(msg.sender, _rarity);

        //update land count
        uint256 rarityIndex = currentSale.landRarityMap[_rarity];
        currentSale.currentLandCounts[rarityIndex]++;

        transferToFeeTo();
    }

    function buyHouse(uint256 _rarity)
        public
        payable
        whenNotPaused
        canBuyHouse(_rarity)
    {
        require(housePriceMap[_rarity] != 0, "Unsupported rarity");
        require(
            msg.value >= housePriceMap[_rarity],
            "buyHouse:: Payment not enough"
        );

        house.mint(msg.sender, _rarity);

        //update land count
        uint256 rarityIndex = currentSale.houseRarityMap[_rarity];
        currentSale.currentHouseCounts[rarityIndex]++;

        transferToFeeTo();
    }

    function buyCombo(uint256 _rarity) external payable whenNotPaused {
        require(
            msg.value >= landPriceMap[_rarity] + housePriceMap[_rarity],
            "buyCombo:: Payment not enough"
        );

        buyLand(_rarity);
        buyHouse(_rarity);

        transferToFeeTo();
    }

    function transferToFeeTo() internal {
        if (address(this).balance > 0) {
            feeTo.sendValue(address(this).balance);
        }
    }

    function getCurrentSaleInfo()
        external
        view
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256[] memory landCountRarities,
            uint256[] memory landCountForSales,
            uint256[] memory currentLandCounts,
            uint256[] memory houseCountRarities,
            uint256[] memory houseCountForSales,
            uint256[] memory currentHouseCounts
        )
    {
        return (
            currentSale.startTime,
            currentSale.endTime,
            currentSale.landCountRarities,
            currentSale.landCountForSales,
            currentSale.currentLandCounts,
            currentSale.houseCountRarities,
            currentSale.houseCountForSales,
            currentSale.currentHouseCounts
        );
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
