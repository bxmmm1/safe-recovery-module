// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/// @title IRecovery interface
/// @author Benjamin H - <benjaminxh@gmail.com>
interface IRecovery {
    event RecoveryAddressAdded(address indexed safe, address indexed recoveryAddress, uint256 recoveryDate);
    event RecoveryDataCleared(address indexed safe);

    /// @notice Adds recovery address and a recovery date
    /// Safe is expected to be a caller
    /// @param recoveryAddress is an address to which safe ownership will be transfered
    /// @param recoveryDate is a timestamp (in seconds) in the future when the recovery process will start
    function addRecovery(address recoveryAddress, uint256 recoveryDate) external;

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
    function getRecoveryDate(address safe) external view returns (uint256);
}