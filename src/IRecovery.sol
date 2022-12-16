// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/// @title IRecovery interface
/// @author Benjamin H - <benjaminxh@gmail.com>
interface IRecovery {
    /// @notice Emitted when the safe owner adds recovery data
    /// @param safe is the address of a safe
    /// @param recoveryAddress is the address to which safe ownership will eventually be transfered
    /// @param recoveryDate is the recovery date timestamp (in seconds) that marks the start transfer ownership
    event RecoveryAddressAdded(address indexed safe, address indexed recoveryAddress, uint64 recoveryDate);

    /// @notice Emitted when the safe owner clears his recovery data
    /// @param safe is the address of a safe
    event RecoveryDataCleared(address indexed safe);

    /// @notice Emitted when the owner changes yearly subscription amount
    /// @param amount is the new yearly subscription amount in wei
    event YearlySubscriptionChanged(uint256 amount);

    /// @notice Thrown when amount is not enough for a desired subscription
    error InsufficientPayment();

    /// @notice Thrown when the recovery date is not valid
    error InvalidRecoveryDate();

    /// @notice Adds recovery address and a recovery date
    /// Safe is expected to be a caller
    /// @param recoveryAddress is an address to which safe ownership will be transfered
    /// @param recoveryDate is a timestamp (in seconds) in the future when the recovery process will start
    function addRecovery(address recoveryAddress, uint64 recoveryDate) external payable;

    /// @notice Clears recovery data
    /// Safe is expected to be a caller
    function clearRecoveryData() external;

    /// @notice Returns recovery address for a `safe`
    /// @param safe is the address of the safe
    /// @return recovery address
    function getRecoveryAddress(address safe) external view returns (address);

    /// @notice Returns recovery date for a `safe`
    /// @param safe is the address of the safe
    /// @return recovery date timestamp (in seconds)
    function getRecoveryDate(address safe) external view returns (uint64);

    /// @notice Returns yearly subscription amount in wei
    /// @return amount in wei
    function getYearlySubscription() external view returns (uint256);
}
