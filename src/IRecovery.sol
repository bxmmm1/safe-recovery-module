// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/// @title IRecovery interface
/// @author Benjamin H - <benjaminxh@gmail.com>
interface IRecovery {
    enum RecoveryType {
        After,
        InactiveFor
    }

    /// @notice Thrown when amount is not enough for a desired subscription
    /// @param amountYouShouldPay amount you should pay for this subscription
    /// Selector 0x0e2e0926
    error InvalidPayment(uint256 amountYouShouldPay);

    /// @notice Thrown when the recovery date is not valid
    /// Selector 0x0ecc12af
    error InvalidRecoveryDate();

    /// @notice Thrown when the caller is unauthorized
    /// Selector 0x82b42900
    error Unauthorized();

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

    /// @notice Emitted when the safe owner adds recovery data with subscription
    /// @param safe is the address of a safe
    /// @param recoveryAddress is the address to which safe ownership will eventually be transfered
    /// @param recoveryDate is the recovery date timestamp (in seconds) that marks the start transfer ownership
    /// @param recoveryType is the recovery type
    event RecoveryAddressAddedWithSubscription(
        address indexed safe, address indexed recoveryAddress, uint64 recoveryDate, RecoveryType recoveryType
    );

    /// @notice Emitted when the new recovery module is added to registry
    /// @param module is the address of the new module
    event RecoveryModuleAdded(address indexed module);

    /// @notice Emitted when the new recovery module is removed from the registry
    /// @param module is the address of the new module
    event RecoveryModuleRemoved(address indexed module);

    /// @notice Emitted when the safe owner clears his recovery data
    /// @param safe is the address of a safe
    event RecoveryDataCleared(address indexed safe);

    /// @notice Emitted when the owner changes subscription amount
    /// @param amount is the new yearly subscription amount in wei
    event SubscriptionAmountChanged(uint256 amount);

    /// @notice Adds recovery address and a recovery date
    /// Safe is expected to be a caller
    /// @param recoveryAddress is an address to which safe ownership will be transfered
    /// @param recoveryDate is a timestamp (in seconds) in the future when the recovery process will start
    function addRecovery(address recoveryAddress, uint40 recoveryDate, RecoveryType recoveryType) external;

    /// @notice Adds recovery address and a recovery date with subscription
    /// Safe is expected to be a caller
    /// @param recoveryAddress is an address to which safe ownership will be transfered
    /// @param recoveryDate is a timestamp (in seconds) in the future when the recovery process will start
    function addRecoveryWithSubscription(address recoveryAddress, uint40 recoveryDate, RecoveryType recoveryType)
        external
        payable;

    /// @notice Clears recovery data
    /// @param safe is the address of the safe
    function clearRecoveryDataFromModule(address safe) external;

    /// @notice Clears recovery data
    /// Safe is expected to be a caller
    function clearRecoveryData() external;

    /// @notice Updates the last activity of a safe
    /// @param safe is the address of the safe
    function updateLastActivity(address safe) external;

    /// @notice Gets the last activity of a safe
    /// @param safe is the address of the safe
    /// @return last activity timestamp (in seconds)
    function getLastActivity(address safe) external view returns (uint256);

    /// @notice Returns recovery address for a `safe`
    /// @param safe is the address of the safe
    /// @return recovery address
    function getRecoveryAddress(address safe) external view returns (address);

    /// @notice Returns recovery date for a `safe`
    /// @param safe is the address of the safe
    /// @return recovery date timestamp (in seconds)
    function getRecoveryDate(address safe) external view returns (uint64);

    /// @notice Returns subscription amount in wei
    /// @return amount in wei
    function getSubscriptionAmount() external view returns (uint256);

    /// @notice Returns if the recovery module is whitelisted
    /// @param module is the address of the module
    /// @return bool
    function isRecoveryModule(address module) external view returns (bool);
}
