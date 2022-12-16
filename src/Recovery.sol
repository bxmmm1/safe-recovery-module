// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IRecovery} from "./IRecovery.sol";

contract Recovery is IRecovery {

    // Yearly subscription amount
    // This amount is related to SMS / Email notification
    // If the user subscribed for 1 year, and 1 year passes
    // Notification service will not work, but the recovery address
    // Is still able to manually interact with RecoveryModule to transfer ownership
    uint256 private _yearlySubscription = 0.1 ether;

    struct RecoveryData {
        address recoveryAddress; // -- slot 0
        uint64 recoveryDate; // -- slot 0
    }

    // [safe address] -> Recovery data
    mapping(address => RecoveryData) private _recovery;

    /// @inheritdoc IRecovery
    function addRecovery(address recoveryAddress, uint64 recoveryDate) external payable {
        if (msg.value == (recoveryDate / 365 days * _yearlySubscription)) {
            revert InsufficientPayment();
        }

        _recovery[msg.sender] = RecoveryData({recoveryAddress: recoveryAddress, recoveryDate: recoveryDate});
        emit RecoveryAddressAdded(msg.sender, recoveryAddress, recoveryDate);
    }

    /// @inheritdoc IRecovery
    function clearRecoveryData() external {
        delete _recovery[msg.sender];
        emit RecoveryDataCleared(msg.sender);
    }

    /// @inheritdoc IRecovery
    function getRecoveryAddress(address safe) external view returns (address) {
        return _recovery[safe].recoveryAddress;
    }

    /// @inheritdoc IRecovery
    function getRecoveryDate(address safe) external view returns (uint64) {
        return _recovery[safe].recoveryDate;
    }

    /// @inheritdoc IRecovery
    function getYearlySubscription() external view returns(uint256) {
        return _yearlySubscription;
    }

    /// @inheritdoc IRecovery
    function setYearlySubscription(uint256 amount) external {
        // TODO: auth
        _yearlySubscription = amount;
        emit YearlySubscrioptionChanged(amount);
    }
}
