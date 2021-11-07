pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IWareHouse.sol";
import "../interfaces/ILand.sol";
import "../lib/BlackholePreventionOwnable.sol";

contract NFTSale is BlackholePreventionOwnable, Initializable, Pausable {
    using Address for address payable;
    using SafeMath for uint256;

    ILand public land;
    IWareHouse public wareHouse;
    address payable public feeTo;

    //rarity => price
    mapping(uint256 => uint256) public landPriceMap;

    //default warehouse price with minimal conditions to contain basic harvested items
    uint256 public wareHousePrice;

    struct CurrentSale {
        uint256 startTime;
        uint256 endTime;
        uint256[] landCountRarities;
        uint256[] landCountForSales;    //corresponding rarity
        mapping(uint256 => uint256) rarityMap;  //mapping from rarity to index + 1 in array landCountRarities
        uint256 wareHouseCountForSale;
        uint256[] currentLandCounts;
        uint256 currentWareHouseCount;
    }
    CurrentSale public currentSale;

    event SetWareHousePrice(uint256 _price, address _setter);
    event SetLandPrice(uint256 _price, uint256 _rarity, address _setter);

    modifier canBuyLand(uint256 _rarity) {
        require(currentSale.startTime <= block.timestamp && block.timestamp <= currentSale.endTime, "Time expired");
        uint256 rarityIndex = currentSale.rarityMap[_rarity];
        require(rarityIndex > 0 && rarityIndex<= currentSale.landCountRarities.length, "invalid rarity");
        require(currentSale.landCountForSales[rarityIndex - 1] > currentSale.currentLandCounts[rarityIndex - 1], "land sold out");
        _;
    }

    modifier canBuyWareHouse() {
        require(currentSale.startTime <= block.timestamp && block.timestamp <= currentSale.endTime, "Time expired");
        require(currentSale.wareHouseCountForSale > currentSale.currentWareHouseCount, "warehouse sold out");
        _;
    }

    function initialize(
        address _wareHouse,
        address _land,
        uint256 _wareHousePrice,
        uint256[] memory _supportedRarities,
        uint256[] memory _landPricesForRarities,
        address payable _feeTo
    ) external initializer {
        wareHouse = IWareHouse(_wareHouse);
        land = ILand(_land);
        feeTo = _feeTo;

        setWareHousePrice(_wareHousePrice);
        setLandPrice(_supportedRarities, _landPricesForRarities);
    }

    function setLandPrice(
        uint256[] memory _supportedRarities,
        uint256[] memory _landPricesForRarities
    ) public onlyOwner {
        require(
            _supportedRarities.length == _landPricesForRarities.length,
            "initialize: Invalid input parameter length"
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

    function setWareHousePrice(uint256 _wareHousePrice) public onlyOwner {
        wareHousePrice = _wareHousePrice;
        emit SetWareHousePrice(_wareHousePrice, msg.sender);
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
        uint256 _wareHouseCountForSale
    ) external onlyOwner {
        require(_landCountRarities.length == _landCountForSales.length, "Invalid input length");
        currentSale.startTime = _startTime > block.timestamp
            ? _startTime
            : block.timestamp;
        currentSale.endTime = currentSale.startTime.add(_duration);

        currentSale.landCountRarities = _landCountRarities;
        currentSale.landCountForSales = _landCountForSales;
        for(uint256 i = 0; i < _landCountRarities.length; i++) {
            currentSale.rarityMap[_landCountRarities[i]] = i + 1;   // + 1 to avoid 0 by default
        }
        
        currentSale.wareHouseCountForSale = _wareHouseCountForSale;

        currentSale.currentLandCounts = new uint256[](_landCountRarities.length);
        currentSale.currentWareHouseCount = 0;
    }

    function updateCurrentSale(
        uint256 _startTime,
        uint256 _duration,
        uint256[] memory _landCountRarities,
        uint256[] memory _landCountForSales,
        uint256 _wareHouseCountForSale
    ) external onlyOwner {
        currentSale.startTime = _startTime;
        currentSale.endTime = currentSale.startTime.add(_duration);

        currentSale.landCountRarities = _landCountRarities;
        currentSale.landCountForSales = _landCountForSales;
        for(uint256 i = 0; i < _landCountRarities.length; i++) {
            currentSale.rarityMap[_landCountRarities[i]] = i;
        }
        
        currentSale.wareHouseCountForSale = _wareHouseCountForSale;
    }

    function buyLand(uint256 _rarity) public payable whenNotPaused canBuyLand(_rarity) {
        require(landPriceMap[_rarity] != 0, "Unsupported rarity");
        require(
            msg.value >= landPriceMap[_rarity],
            "buyLand:: Payment not enough"
        );

        land.mint(msg.sender, _rarity);

        //update land count
        uint256 rarityIndex = currentSale.rarityMap[_rarity];
        currentSale.currentLandCounts[rarityIndex]++;

        transferToFeeTo();
    }

    function buyWareHouse() public payable whenNotPaused canBuyWareHouse {
        require(wareHousePrice != 0, "Unsupported rarity");
        require(
            msg.value >= wareHousePrice,
            "buyWareHouse:: Payment not enough"
        );

        wareHouse.mint(msg.sender);
        currentSale.currentWareHouseCount++;

        transferToFeeTo();
    }

    function buyCombo(uint256 _rarity) external payable whenNotPaused {
        require(
            msg.value >= landPriceMap[_rarity] + wareHousePrice,
            "buyCombo:: Payment not enough"
        );

        buyLand(_rarity);
        buyWareHouse();

        transferToFeeTo();
    }

    function transferToFeeTo() internal {
        if (address(this).balance > 0) {
            feeTo.sendValue(address(this).balance);
        }
    }
}
