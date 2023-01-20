// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {GnosisSafe} from "safe-contracts/GnosisSafe.sol";

/// @title IRecoveryModule interface
/// @author Benjamin H - <benjaminxh@gmail.com>
interface IRecoveryModule {
    enum RecoveryType {
        After,
        InactiveFor
    }

    /// @notice Thrown when amount is not enough for a desired subscription
    /// @param amountYouShouldPay amount you should pay for this subscription
    /// Selector 0x0e2e0926
    error InvalidPayment(uint256 amountYouShouldPay);

    /// @notice Thrown when the current time is lower than `timeLockExpiration`
    /// Selector 0x085de625
    error TooEarly();

    /// @notice Thrown when the address is address(0)
    /// Selector 0xe6c4247b
    error InvalidAddress();

    /// @notice Thrown when the Safe transaction failed
    /// Selector 0xbf961a28
    error TransactionFailed();

    /// @notice Transfer ownership is already initiated
    /// Selector 0x77fcbe52
    error TransferOwnershipAlreadyInitiated();

    /// @notice Thrown when the recovery address iz address(0)
    /// Or the recovery address is the first owner of safe
    /// That is not possible with current implementation
    /// Selector 0xa61421a2
    error InvalidRecoveryAddress();

    /// @notice Emitted when the safe owner adds recovery data
    /// @param safe is the address of a safe
    /// @param recoveryAddress is the address to which safe ownership will eventually be transfered
    /// @param recoveryDate is the recovery date timestamp (in seconds) that marks the start transfer ownership
    /// @param recoveryType is the recovery type
    event RecoveryAddressAdded(
        address indexed safe, address indexed recoveryAddress, uint64 recoveryDate, RecoveryType recoveryType
    );

    /// @notice Emitted when the safe owner clears his recovery data
    /// @param safe is the address of a safe
    event RecoveryDataCleared(address indexed safe);

    /// @notice Emitted when the transfer ownership is initiated
    /// @param safe is the safe address
    /// @param timeLockExpiration is the timestamp (seconds) when the timelock expires
    event TransferOwnershipInitiated(address indexed safe, uint256 timeLockExpiration);

    /// @notice Emitted when the transfer ownership is finalized
    /// @param safe is the safe address
    event TransferOwnershipFinalized(address indexed safe);

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

    /// @notice Gets the last activity of a safe
    /// @param safe is the address of the safe
    /// @return last activity timestamp (in seconds)
    function getLastActivity(address safe) external view returns (uint256);

    /// @notice Gets the recovery type
    /// @param safe is the address of the safe
    /// @return recovery type
    function getRecoveryType(address safe) external view returns (RecoveryType);

    /// @notice Returns recovery address for a `safe`
    /// @param safe is the address of the safe
    /// @return recovery address
    function getRecoveryAddress(address safe) external view returns (address);

    /// @notice Returns recovery date for a `safe`
    /// @param safe is the address of the safe
    /// @return recovery date timestamp (in seconds)
    function getRecoveryDate(address safe) external view returns (uint64);

    /// @notice Adds recovery address and a recovery date
    /// Safe is expected to be a caller
    /// @param recoveryAddress is an address to which safe ownership will be transfered
    /// @param recoveryDate is a timestamp (in seconds) in the future when the recovery process will start
    function addRecovery(address recoveryAddress, uint40 recoveryDate, RecoveryType recoveryType) external payable;
}
