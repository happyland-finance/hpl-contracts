pragma solidity ^0.8.0;
import "../../interfaces/ITransferFee.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TransferFeeHPW is ITransferFee, Ownable {
    mapping(address => bool) public zeroFeeList;

    event ZeroFeeList(address _addr, bool val);
    uint256 public stakeRewardFee;
    uint256 public liquidityFee;
    uint256 public burnFee;

    constructor() {
        zeroFeeList[msg.sender] = true;
        stakeRewardFee = 0;
        liquidityFee = 300;
        burnFee = 200;
    }

    function setZeroFeeList(address[] memory _addrs, bool _val)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            zeroFeeList[_addrs[i]] = _val;
            emit ZeroFeeList(_addrs[i], _val);
        }
    }

    function setTransferFees(
        uint256 _stakeRewardFee,
        uint256 _liquidityFee,
        uint256 _burnFee
    ) external onlyOwner {
        stakeRewardFee = _stakeRewardFee;
        liquidityFee = _liquidityFee;
        burnFee = _burnFee;
    }

    function getTransferFees(
        address sender,
        address recipient,
        uint256 amount
    )
        external
        view
        override
        returns (
            uint256 _stakeRewardFee,
            uint256 _liquidityFee,
            uint256 _burnFee
        )
    {
        if (zeroFeeList[sender] || zeroFeeList[recipient]) return (0, 0, 0);
        return (stakeRewardFee, liquidityFee, burnFee); //0.5%
    }
}
