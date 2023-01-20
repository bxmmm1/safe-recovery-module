// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Enum} from "safe-contracts/common/Enum.sol";
import {GnosisSafe} from "safe-contracts/GnosisSafe.sol";
import {Guard} from "safe-contracts/base/GuardManager.sol";
import {OwnerManager} from "safe-contracts/base/OwnerManager.sol";
import {IRecoveryModule} from "./IRecoveryModule.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @author Benjamin H - <benjaminxh@gmail.com>
contract RecoveryModule is IRecoveryModule, Guard {
    using SafeTransferLib for address;

    // Timelock period for ownership transfer
    uint256 public immutable timeLock;

    struct RecoveryData {
        address recoveryAddress; // slot 0
        uint40 recoveryDate; // slot 0
        RecoveryType recoveryType; // slot 0
        uint40 lastActivity; // slot 0
        uint256 recoveryValue; // slot 1
    }

    // [Safe address] -> Recovery data
    mapping(address => RecoveryData) private _recoveryData;

    // [Safe address] -> timelockExpiration timestamp in seconds
    mapping(address => uint256) private _recoveryTimelock;

    constructor(uint256 lock) {
        timeLock = lock;
    }

    /// @inheritdoc IRecoveryModule
    function addRecovery(address recoveryAddress, uint40 recoveryDate, RecoveryType recoveryType) external payable {
        if (recoveryAddress == address(0)) {
            revert InvalidRecoveryAddress();
        }

        _recoveryData[msg.sender] = RecoveryData({
            recoveryAddress: recoveryAddress,
            recoveryDate: recoveryDate,
            recoveryType: recoveryType,
            lastActivity: uint40(block.timestamp),
            recoveryValue: getRecoveryValue(msg.sender) + msg.value // new amount is previous + this
        });

        emit RecoveryAddressAdded(msg.sender, recoveryAddress, recoveryDate, recoveryType);
    }

    /// @inheritdoc IRecoveryModule
    function clearRecovery() external {
        uint256 amount = getRecoveryValue(msg.sender);
        _clearRecovery(msg.sender);
        msg.sender.safeTransferETH(amount);
        emit EtherTransferred(msg.sender);
    }

    /// @inheritdoc IRecoveryModule
    function initiateTransferOwnership(address safe) external {
        // This is done to prevent somebody from extending timeLockExpiration value
        if (_recoveryTimelock[safe] != 0) {
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

        _recoveryTimelock[safe] = timeLockExpiration;
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

        uint256 amount = getRecoveryValue(safeAddress);

        // Clear recovery data
        _clearRecovery(safeAddress);

        msg.sender.safeTransferETH(amount);

        emit TransferOwnershipFinalized(safeAddress);
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
        delete _recoveryTimelock[safe];
        delete _recoveryData[safe];
        emit RecoveryDataCleared(safe);
    }

    // View functions

    /// @inheritdoc IRecoveryModule
    function getTimelockExpiration(address safe) public view returns (uint256) {
        return _recoveryTimelock[safe];
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

    /// @inheritdoc IRecoveryModule
    function getRecoveryValue(address safe) public view returns (uint256) {
        return _recoveryData[safe].recoveryValue;
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
