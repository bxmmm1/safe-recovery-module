// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/// @title IRecovery interface
/// @author Benjamin H - <benjaminxh@gmail.com>
interface IRecovery {
    event RecoveryAddressAdded(address indexed safe, address indexed recoveryAddress, uint64 recoveryDate);
    event RecoveryDataCleared(address indexed safe);
    event YearlySubscrioptionChanged(uint256 amount);
    
    error InsufficientPayment();

    /// @notice Adds recovery address and a recovery date
    /// Safe is expected to be a caller
    /// @param recoveryAddress is an address to which safe ownership will be transfered
    /// @param recoveryDate is a timestamp (in seconds) in the future when the recovery process will start
    function addRecovery(address recoveryAddress, uint64 recoveryDate) external payable;

    /// @notice Clears recovery data
    /// Safe is expected to be a caller
    function clearRecoveryData() external;

    /// @notice Sets yearly subscription amount data
    /// @param amount in wei
    function setYearlySubscription(uint256 amount) external;

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
