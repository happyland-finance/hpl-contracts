pragma solidity ^0.8.0;

import "../lib/Upgradeable.sol";
import "../lib/BlackholePreventionOwnableUpgradeable.sol";
contract DevFund is Upgradeable, BlackholePreventionOwnableUpgradeable {
    function initialize() public initializer {
        initOwner();
    }

    receive() external payable {
    }

    fallback() external payable {
    }
}