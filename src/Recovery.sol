// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IRecovery} from "./IRecovery.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Recovery is IRecovery, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant MULTISIG = keccak256("MULTISIG");
    bytes32 public constant CREATOR = keccak256("CREATOR");

    // Subscription amount used to support web2 and notification infrastructure
    uint256 private _subscriptionAmount = 0.1 ether;

    struct RecoveryData {
        address recoveryAddress;
        uint64 recoveryDate;
        RecoveryType recoveryType;
        uint256 lastActivity;
    }

    // [safe address] -> Recovery data
    mapping(address => RecoveryData) private _recovery;

    EnumerableSet.AddressSet private _recoveryModules;

    constructor() {
        _setupRole(CREATOR, msg.sender);
        _setupRole(MULTISIG, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyRecoveryModule() {
        if (!_recoveryModules.contains(msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    function addRecoveryModule(address module) external onlyRole(MULTISIG) {
        _recoveryModules.add(module);
        emit RecoveryModuleAdded(module);
    }

    function removeRecoveryModule(address module) external onlyRole(MULTISIG) {
        _recoveryModules.remove(module);
        emit RecoveryModuleRemoved(module);
    }

    /// @inheritdoc IRecovery
    function addRecovery(address recoveryAddress, uint64 recoveryDate, RecoveryType recoveryType) external {
        if (recoveryAddress == address(0)) {
            revert InvalidRecoveryAddress();
        }

        _recovery[msg.sender] = RecoveryData({
            recoveryAddress: recoveryAddress,
            recoveryDate: recoveryDate,
            recoveryType: recoveryType,
            lastActivity: block.timestamp
        });

        emit RecoveryAddressAdded(msg.sender, recoveryAddress, recoveryDate, recoveryType);
    }

    /// @inheritdoc IRecovery
    function addRecoveryWithSubscription(address recoveryAddress, uint64 recoveryDate, RecoveryType recoveryType)
        external
        payable
    {
        uint256 amount = _calculatePaymentAmount(recoveryDate, _subscriptionAmount, recoveryType);

        if (msg.value != amount) {
            revert InvalidPayment(amount);
        }

        if (recoveryAddress == address(0)) {
            revert InvalidRecoveryAddress();
        }

        _recovery[msg.sender] = RecoveryData({
            recoveryAddress: recoveryAddress,
            recoveryDate: recoveryDate,
            recoveryType: recoveryType,
            lastActivity: block.timestamp
        });

        emit RecoveryAddressAddedWithSubscription(msg.sender, recoveryAddress, recoveryDate, recoveryType);
    }

    /// @inheritdoc IRecovery
    function updateLastActivity(address safe) external onlyRecoveryModule {
        _recovery[safe].lastActivity = block.timestamp;
    }

    /// @inheritdoc IRecovery
    function getLastActivity(address safe) external view returns (uint256) {
        return _recovery[safe].lastActivity;
    }

    /// @inheritdoc IRecovery
    function clearRecoveryData() external {
        delete _recovery[msg.sender];
        emit RecoveryDataCleared(msg.sender);
    }

    /// @inheritdoc IRecovery
    function getRecoveryAddress(address safe) external view returns (address) {
        return _recovery[safe].recoveryAddress;
    }

    /// @inheritdoc IRecovery
    function getRecoveryDate(address safe) external view returns (uint64) {
        return _recovery[safe].recoveryDate;
    }

    function getRecoveryType(address safe) external view returns (RecoveryType) {
        return _recovery[safe].recoveryType;
    }

    /// @inheritdoc IRecovery
    function getSubscriptionAmount() external view returns (uint256) {
        return _subscriptionAmount;
    }

    /// @inheritdoc IRecovery
    function isRecoveryModule(address module) external view returns (bool) {
        return _recoveryModules.contains(module);
    }

    /// @notice Sets subscription amount
    /// @param amount in wei
    function setSubscription(uint256 amount) external onlyRole(CREATOR) {
        _subscriptionAmount = amount;
        emit SubscriptionAmountChanged(amount);
    }

    /// @notice Withdraws eth from the contract
    /// @param amount to withdraw
    /// @param to address
    function withdrawFunds(uint256 amount, address to) external onlyRole(CREATOR) {
        (bool success,) = to.call{value: amount}("");
        require(success);
    }

    function _calculatePaymentAmount(uint64 recoveryDate, uint256 yearlyFee, RecoveryType recoveryType)
        private
        view
        returns (uint256)
    {
        if (recoveryType == RecoveryType.After) {
            uint256 yearsOfSubscription = (uint256(recoveryDate) - block.timestamp) / 365 days;
            // +1 is because of solidity's rounding
            return (yearsOfSubscription + 1) * yearlyFee;
        }

        // +1 is because of solidity's rounding
        uint256 monthsOfSubscription = uint256(recoveryDate) / 30 days;
        return (monthsOfSubscription + 1) * yearlyFee;
    }
}
