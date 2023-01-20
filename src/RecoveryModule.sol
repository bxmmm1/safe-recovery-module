// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Enum} from "safe-contracts/common/Enum.sol";
import {GnosisSafe} from "safe-contracts/GnosisSafe.sol";
import {Guard} from "safe-contracts/base/GuardManager.sol";
import {OwnerManager} from "safe-contracts/base/OwnerManager.sol";
import {IRecoveryModule} from "./IRecoveryModule.sol";

/// @author Benjamin H - <benjaminxh@gmail.com>
contract RecoveryModule is IRecoveryModule, Guard {
    // Timelock period for ownership transfer
    uint256 public immutable timeLock;

    struct RecoveryData {
        address recoveryAddress;
        uint40 recoveryDate;
        RecoveryType recoveryType;
        uint40 lastActivity;
    }

    uint256 private _subscriptionAmount = 0.1 ether;

    // [safe address] -> Recovery data
    mapping(address => RecoveryData) private _recoveryData;

    // Safe address -> timelockExpiration timestamp
    mapping(address => uint256) private _recovery;

    constructor(uint256 lock) {
        timeLock = lock;
    }

    /// @inheritdoc IRecoveryModule
    function addRecovery(address recoveryAddress, uint40 recoveryDate, RecoveryType recoveryType) external payable {
        if (msg.value != _subscriptionAmount) {
            revert InvalidPayment(_subscriptionAmount);
        }

        if (recoveryAddress == address(0)) {
            revert InvalidRecoveryAddress();
        }

        _recoveryData[msg.sender] = RecoveryData({
            recoveryAddress: recoveryAddress,
            recoveryDate: recoveryDate,
            recoveryType: recoveryType,
            lastActivity: uint40(block.timestamp)
        });

        emit RecoveryAddressAdded(msg.sender, recoveryAddress, recoveryDate, recoveryType);
    }

    function clearRecovery() external {
        _clearRecovery(msg.sender);
    }

    /// @inheritdoc IRecoveryModule
    function initiateTransferOwnership(address safe) external {
        // This is done to prevent somebody from extending timeLockExpiration value
        if (_recovery[safe] != 0) {
            revert TransferOwnershipAlreadyInitiated();
        }

        if (getRecoveryAddress(safe) == address(0)) {
            revert InvalidAddress();
        }

        if (getRecoveryType(safe) == IRecoveryModule.RecoveryType.InactiveFor) {
            _ensureSafeIsInactive(safe);
        } else {
            _ensureRecoveryDateHasPassed(safe);
        }

        uint256 timeLockExpiration = block.timestamp + timeLock;

        _recovery[safe] = timeLockExpiration;
        emit TransferOwnershipInitiated(safe, timeLockExpiration);
    }

    /// @inheritdoc IRecoveryModule
    function finalizeTransferOwnership(address safeAddress) external {
        address newOwner = getRecoveryAddress(safeAddress);
        // owner != address zero means that the owner did not cancel transfer ownership
        if (newOwner == address(0)) {
            revert InvalidAddress();
        }

        // Make sure that timelock has passed
        if (block.timestamp < getTimelockExpiration(safeAddress)) {
            revert TooEarly();
        }
        
        // Clear recovery data
        _clearRecovery(safeAddress);
        delete _recovery[safeAddress];

        GnosisSafe safe = GnosisSafe(payable(safeAddress));
        address[] memory owners = safe.getOwners();

        // start removing from the last owner, untill the last one is left
        for (uint256 i = (owners.length - 1); i > 0; --i) {
            bool s = safe.execTransactionFromModule({
                to: safeAddress,
                value: 0,
                // changes threshold to 1 so the safe becomes 1/1 for the new owner
                data: abi.encodeCall(OwnerManager.removeOwner, (owners[i - 1], owners[i], 1)),
                operation: Enum.Operation.Call
            });
            if (!s) {
                revert TransactionFailed();
            }
        }

        // We've removed all other owners, only first owner is left
        // If it is not the same address do a swapOwner
        if (newOwner != owners[0]) {
            bool success = safe.execTransactionFromModule({
                to: safeAddress,
                value: 0,
                // Previous address for only owner is sentinel address -> address(0x1)
                data: abi.encodeCall(OwnerManager.swapOwner, (address(0x1), owners[0], newOwner)),
                operation: Enum.Operation.Call
            });
            if (!success) {
                revert TransactionFailed();
            }
        }

        emit TransferOwnershipFinalized(safeAddress);
    }

    /// @inheritdoc IRecoveryModule
    function cancelTransferOwnership() external {
        delete _recovery[msg.sender];
        emit TransferOwnershipCanceled(msg.sender);
    }

    function checkTransaction(
        address,
        uint256,
        bytes memory,
        Enum.Operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address
    ) external {
        // do nothing, required by `Guard` interface
    }

    /// @dev Required by `Guard` interface from Safe
    /// Records last safe activity
    function checkAfterExecution(bytes32, bool) external {
        _recoveryData[msg.sender].lastActivity = uint40(block.timestamp);
    }

    function _clearRecovery(address safe) internal {
        delete _recovery[safe];
        emit RecoveryDataCleared(safe);
    }

    // View functions

    /// @inheritdoc IRecoveryModule
    function getTimelockExpiration(address safe) public view returns (uint256) {
        return _recovery[safe];
    }

    /// @inheritdoc IRecoveryModule
    function getRecoveryAddress(address safe) public view returns (address) {
        return _recoveryData[safe].recoveryAddress;
    }

    /// @inheritdoc IRecoveryModule
    function getRecoveryDate(address safe) public view returns (uint64) {
        return _recoveryData[safe].recoveryDate;
    }

    /// @inheritdoc IRecoveryModule
    function getRecoveryType(address safe) public view returns (RecoveryType) {
        return _recoveryData[safe].recoveryType;
    }

    /// @inheritdoc IRecoveryModule
    function getLastActivity(address safe) public view returns (uint256) {
        return _recoveryData[safe].lastActivity;
    }

    function getSubscriptionAmount() external view returns (uint256) {
        return _subscriptionAmount;
    }

    function _ensureSafeIsInactive(address safe) private view {
        // Recovery date represents for how long the safe must be inactive to not revert
        if (block.timestamp - getLastActivity(safe) < getRecoveryDate(safe)) {
            revert TooEarly();
        }
    }

    function _ensureRecoveryDateHasPassed(address safe) private view {
        if (block.timestamp < getRecoveryDate(safe)) {
            revert TooEarly();
        }
    }
}
