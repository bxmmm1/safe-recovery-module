// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Enum} from "safe-contracts/common/Enum.sol";
import {GnosisSafe} from "safe-contracts/GnosisSafe.sol";
import {Guard} from "safe-contracts/base/GuardManager.sol";
import {OwnerManager} from "safe-contracts/base/OwnerManager.sol";
import {Recovery} from "./Recovery.sol";
import {IRecovery} from "./IRecovery.sol";
import {IRecoveryModule} from "./IRecoveryModule.sol";

/// @author Benjamin H - <benjaminxh@gmail.com>
contract RecoveryModule is IRecoveryModule, Guard {
    // Recovery Registry
    Recovery public immutable recoveryRegistry;

    // Timelock period for ownership transfer
    uint256 public immutable timeLock;

    // Safe address -> timelockExpiration timestamp
    mapping(address => uint256) private _recovery;

    constructor(address recoveryAddress, uint256 lock) {
        recoveryRegistry = Recovery(recoveryAddress);
        timeLock = lock;
    }

    /// @inheritdoc IRecoveryModule
    function finalizeTransferOwnership(address safeAddress) external {
        address newOwner = recoveryRegistry.getRecoveryAddress(safeAddress);
        // If the new owner is not zero
        // that means that the owner did not cancel transfer ownership
        // we don't need to validate safe inactivity / or other dates
        // just newOwner and that timelock expiration is passed
        if (newOwner == address(0)) {
            revert InvalidAddress();
        }

        // Make sure that timelock has passed
        if (block.timestamp < getTimelockExpiration(safeAddress)) {
            revert TooEarly();
        }

        recoveryRegistry.clearRecoveryDataFromModule(safeAddress);
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
    function initiateTransferOwnership(address safe) external {
        // This is done to prevent somebody from extending timeLockExpiration value
        if (_recovery[safe] != 0) {
            revert TransferOwnershipAlreadyInitiated();
        }

        if (recoveryRegistry.getRecoveryAddress(safe) == address(0)) {
            revert InvalidAddress();
        }

        if (recoveryRegistry.getRecoveryType(safe) == IRecovery.RecoveryType.InactiveFor) {
            _ensureSafeIsInactive(safe);
        } else {
            _ensureRecoveryDateHasPassed(safe);
        }

        uint256 timeLockExpiration = block.timestamp + timeLock;

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

    /// @notice Required by `Guard` interface
    /// Is used to record last activity of a Safe
    function checkAfterExecution(bytes32, bool) external {
        recoveryRegistry.updateLastActivity(msg.sender);
    }

    function _ensureSafeIsInactive(address safe) private view {
        // Recovery date represents for how long the safe must be inactive to not revert
        if (block.timestamp - recoveryRegistry.getLastActivity(safe) < recoveryRegistry.getRecoveryDate(safe)) {
            revert TooEarly();
        }
    }

    function _ensureRecoveryDateHasPassed(address safe) private view {
        if (block.timestamp < recoveryRegistry.getRecoveryDate(safe)) {
            revert TooEarly();
        }
    }
}
