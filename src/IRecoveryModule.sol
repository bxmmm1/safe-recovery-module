// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {GnosisSafe} from "safe-contracts/GnosisSafe.sol";

/// @title IRecoveryModule interface
/// @author Benjamin H - <benjaminxh@gmail.com>
interface IRecoveryModule {
    /// @notice Thrown when the current time is lower than `timeLockExpiration`
    error TooEarly();

    /// @notice Thrown when the address is address(0)
    error InvalidAddress();

    /// @notice Thrown when the Safe transaction failed
    error TransactionFailed();

    /// @notice Transfer ownership is already initiated
    error TransferOwnershipAlreadyInitiated();

    /// @notice Emitted when the transfer ownership is initiated
    /// @param safe is the safe address
    /// @param timeLockExpiration is the timestamp (seconds) when the timelock expires
    event TransferOwnershipInitiated(address indexed safe, uint256 timeLockExpiration);

    /// @notice Emitted when the Safe cancels ownership transfer
    /// @param safe is the safe address
    event TransferOwnershipCanceled(address indexed safe);

    /// @notice Cancels the ownership transfer when called by Safe
    function cancelTransferOwnership() external;

    /// @notice Initiates ownership transfer
    /// @param safe is the safe address
    function initiateTransferOwnership(address safe) external;

    /// @notice Finalizes ownership transfer
    /// @param safe is the safe address
    function finalizeTransferOwnership(address safe) external;

    /// @notice Returns the timelock expiration
    /// @param safe is the safe address
    /// @return timestamp in seconds
    function getTimelockExpiration(address safe) external view returns (uint256);
}
