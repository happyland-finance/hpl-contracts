pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/BlackholePrevention.sol";
import "../interfaces/ILand.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract HappyLandFaucet is Ownable, BlackholePrevention, Initializable{
    address public hpl;
    address public hpw;
    address public land;

    uint256 public maxLandClaim = 50000;

    function initialize(
        address _hpl,
        address _hpw,
        address _land
    ) external initializer {
        hpl = _hpl;
        hpw = _hpw;
        land = _land;
    }


    mapping (address => bool) public claimedLand;
    mapping (address => uint256) public claimedToken;

    uint256 public maxHPLFaucet = 1e21;
    uint256 public maxHPWFaucet = 1e22;

    function faucetLand() public {
        require(!claimedLand[msg.sender], "You are already have a land");

        claimedLand[msg.sender] = true;
        for (uint256 i = maxLandClaim; i < maxLandClaim + 5; i++) {
            ILand(land).mint(msg.sender, i);
        }
        maxLandClaim = maxLandClaim + 5;
    }

    function faucetToken() public {
        require(block.timestamp - 1 days >= claimedToken[msg.sender], "You can claim 1 time per day");
        IERC20(hpl).transfer(msg.sender, maxHPLFaucet);
        IERC20(hpw).transfer(msg.sender, maxHPWFaucet);
        claimedToken[msg.sender] = block.timestamp;
    }

    function nextClaimToken(address claimer) public view returns (uint256){
        if (claimedToken[claimer] == 0) {
            return 0;
        }
        return claimedToken[claimer] + 1 days;
    }

    function setMaxLandClaim(uint256 max) onlyOwner public {
        maxLandClaim = max;
    }
    function setMaxFaucet(uint256 _hpl, uint256 _hpw) onlyOwner public {
        maxHPLFaucet = _hpl;
        maxHPWFaucet = _hpw;
    }

    function setLand(address _land) external onlyOwner {
        land = _land;
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