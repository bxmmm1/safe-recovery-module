// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Enum} from "safe-contracts/common/Enum.sol";
import {GnosisSafe} from "safe-contracts/GnosisSafe.sol";
import {OwnerManager} from "safe-contracts/base/OwnerManager.sol";
import {Recovery} from "./Recovery.sol";
import {IRecoveryModule} from "./IRecoveryModule.sol";

/// @author Benjamin H - <benjaminxh@gmail.com>
contract RecoveryModule is IRecoveryModule {
    // Timelock period for ownership transfer
    uint256 private immutable _timeLock;

    // Recovery Registry
    Recovery public immutable recoveryRegistry;

    // Safe address -> timelockExpiration timestamp
    mapping(address => uint256) private _recovery;

    constructor(address recoveryAddress, uint256 timeLock) {
        recoveryRegistry = Recovery(recoveryAddress);
        _timeLock = timeLock;
    }

    /// @inheritdoc IRecoveryModule
    function finalizeTransferOwnership(address safeAddress) external {
        if (block.timestamp < getTimelockExpiration(safeAddress)) {
            revert TooEarly();
        }

        address newOwner = recoveryRegistry.getRecoveryAddress(safeAddress);
        if (newOwner == address(0)) {
            revert InvalidAddress();
        }

        recoveryRegistry.clearRecoveryData();

        GnosisSafe safe = GnosisSafe(payable(safeAddress));
        address[] memory owners = safe.getOwners();

        // start removing from the last owner, untill the last one is left
        for (uint256 i = (owners.length - 1); i > 0; --i) {
            // changes threshold to 1 so the safe becomes 1/1 for the new owner
            bytes memory callData = abi.encodeCall(OwnerManager.removeOwner, (owners[i - 1], owners[i], 1));
            bool success = safe.execTransactionFromModule({to: address(safe), value: 0, data: callData, operation: Enum.Operation.Call});
            if (!success) {
                revert TransactionFailed();
            }
        }

        // Swap the last owner with the new newOwner
        // Previous address for only owner is sentinel address -> address(0x1)
        bytes memory data = abi.encodeCall(OwnerManager.swapOwner, (address(0x1), owners[0], newOwner));
        bool success =
            safe.execTransactionFromModule({to: address(safe), value: 0, data: data, operation: Enum.Operation.Call});

        if (!success) {
            revert TransactionFailed();
        }
    }

    /// @inheritdoc IRecoveryModule
    function initiateTransferOwnership(address safe) external {
        // This is done to prevent somebody from extending timeLockExpiration value
        if (_recovery[safe] != 0) {
            revert TransferOwnershipAlreadyInitiated();
        }

        if (block.timestamp < recoveryRegistry.getRecoveryDate(safe)) {
            revert TooEarly();
        }

        if (recoveryRegistry.getRecoveryAddress(safe) == address(0)) {
            revert InvalidAddress();
        }

        uint256 timeLockExpiration = block.timestamp + _timeLock;

        _recovery[safe] = timeLockExpiration;
        emit TransferOwnershipInitiated(safe, timeLockExpiration);
    }

    /// @inheritdoc IRecoveryModule
    function cancelTransferOwnership() external {
        delete _recovery[msg.sender];
        emit TransferOwnershipCanceled(msg.sender);
    }

    /// @inheritdoc IRecoveryModule
    function getTimelockExpiration(address safe) public view returns (uint256) {
        return _recovery[safe];
    }

    /// @inheritdoc IRecoveryModule
    function getTimelock() external view returns (uint256) {
        return _timeLock;
    }
}
