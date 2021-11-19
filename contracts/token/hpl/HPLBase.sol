pragma solidity ^0.8.0;

import "../TokenBurnableUpgradeable.sol";
import "../../interfaces/ITokenHook.sol";
import "../../lib/BlackholePrevention.sol";
import "../../lib/Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract HPLBase is Upgradeable, TokenBurnableUpgradeable, BlackholePrevention {
    ITokenHook public tokenHook;
    address public stakingRewardTreasury;
    mapping(address => bool) public pancakePairs;

    function initialize(
        address _tokenReceiver,
        address _stakingRewardTreasury,
        address _tokenHook
    ) public initializer {
        initOwner();
        __ERC20_init("HappyLand.Finance", "HPL");

        //supply 400M
        _mint(_tokenReceiver, 400 * 1000000 * 10**decimals());
        stakingRewardTreasury = _stakingRewardTreasury;
        tokenHook = ITokenHook(_tokenHook);
    }

    function setTokenHook(address _addr) external onlyOwner {
        tokenHook = ITokenHook(_addr);
    }

    function setStakingRewardTreasury(address _stakingRewardTreasury)
        external
        onlyOwner
    {
        stakingRewardTreasury = _stakingRewardTreasury;
    }

    function setPancakePairs(address[] memory _pancakePairs, bool val)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _pancakePairs.length; i++) {
            pancakePairs[_pancakePairs[i]] = val;
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        if (!pancakePairs[sender] && address(tokenHook) != address(0)) {
            tokenHook.addLiquidity();
        }

        unchecked {
            _balances[sender] = senderBalance - amount;
        }

        if (
            address(tokenHook) != address(0) &&
            sender != address(tokenHook) &&
            recipient != address(tokenHook)
        ) {
            (
                uint256 stakeFee,
                uint256 liquidityFee,
                uint256 burnFee
            ) = tokenHook.getTransferFees(sender, recipient, amount);
            uint256 burnAmount = (amount * burnFee) / 10000;
            uint256 stakingRewardTreasuryAmount = (amount * stakeFee) / 10000;
            uint256 liquidityHolderAmount = (amount * liquidityFee) / 10000;
            //burn
            _totalSupply -= burnAmount;
            //treasury
            _balances[stakingRewardTreasury] += stakingRewardTreasuryAmount;
            //liquidityFee
            _balances[address(tokenHook)] += liquidityHolderAmount;

            _balances[recipient] +=
                amount -
                burnAmount -
                stakingRewardTreasuryAmount -
                liquidityHolderAmount;

            emit Transfer(sender, address(0), burnAmount);
            emit Transfer(
                sender,
                stakingRewardTreasury,
                stakingRewardTreasuryAmount
            );
            emit Transfer(sender, address(tokenHook), liquidityHolderAmount);
            emit Transfer(
                sender,
                recipient,
                amount -
                    burnAmount -
                    stakingRewardTreasuryAmount -
                    liquidityHolderAmount
            );
        } else {
            _balances[recipient] += amount;
            emit Transfer(sender, recipient, amount);
        }
        _afterTokenTransfer(sender, recipient, amount);
    }

    //rescue loss token
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
