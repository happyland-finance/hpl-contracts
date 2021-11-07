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
contract NFTCreator is BlackholePreventionOwnable, Initializable, Pausable {
    using Address for address payable;

    ILand public land;
    IWareHouse public wareHouse;
    address payable public feeTo;

    //rarity => price
    mapping(uint256 => uint256) public landPriceMap;

    //default warehouse price with minimal conditions to contain basic harvested items
    uint256 public wareHousePrice;  

    event SetWareHousePrice(uint256 _price, address _setter);
    event SetLandPrice(uint256 _price, uint256 _rarity, address _setter);

    function initialize(address _wareHouse, address _land, uint256 _wareHousePrice, uint256[] memory _supportedRarities, uint256[] memory _landPricesForRarities, address payable _feeTo) external initializer {
        wareHouse = IWareHouse(_wareHouse);
        land = ILand(_land);
        feeTo = _feeTo;
        
        setWareHousePrice(_wareHousePrice);
        setLandPrice(_supportedRarities, _landPricesForRarities);
    }

    function setLandPrice(uint256[] memory _supportedRarities, uint256[] memory _landPricesForRarities) public onlyOwner {
        require(_supportedRarities.length == _landPricesForRarities.length, "initialize: Invalid input parameter length");
        for(uint256 i = 0; i < _supportedRarities.length; i++) {
            landPriceMap[_supportedRarities[i]] = _landPricesForRarities[i];
            emit SetLandPrice(_landPricesForRarities[i], _supportedRarities[i], msg.sender);
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

    function buyLand(uint256 _rarity) public payable whenNotPaused {
        require(landPriceMap[_rarity] != 0, "Unsupported rarity");
        require(msg.value >= landPriceMap[_rarity], "buyLand:: Payment not enough");

        land.mint(msg.sender, _rarity);

        transferToFeeTo();
    }

    function buyWareHouse() public payable whenNotPaused {
        require(wareHousePrice != 0, "Unsupported rarity");
        require(msg.value >= wareHousePrice, "buyWareHouse:: Payment not enough");

        wareHouse.mint(msg.sender);

        transferToFeeTo();
    }

    function buyCombo(uint256 _rarity) external payable whenNotPaused {
        require(msg.value >= landPriceMap[_rarity] + wareHousePrice, "buyCombo:: Payment not enough");

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