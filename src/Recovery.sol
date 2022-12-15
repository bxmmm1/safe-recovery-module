// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IRecovery} from "./IRecovery.sol";

contract Recovery is IRecovery {
    struct RecoveryData {
        address recoveryAddress;
        uint256 recoveryDate;
    }

    mapping(address => RecoveryData) private _recovery;

    /// @inheritdoc IRecovery
    function addRecovery(address recoveryAddress, uint256 recoveryDate) external {
        // TODO: payment here? ERC20 / ETH?
        // Use oracle?
        
        _recovery[msg.sender] = RecoveryData({recoveryAddress: recoveryAddress, recoveryDate: recoveryDate});
        emit RecoveryAddressAdded(msg.sender, recoveryAddress, recoveryDate);
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
    function getRecoveryDate(address safe) external view returns (uint256) {
        return _recovery[safe].recoveryDate;
    }
}
