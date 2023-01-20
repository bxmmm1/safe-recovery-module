// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract T {
    struct RecoveryData {
        uint128 whatever;
        uint128 lastActivity;
    }

    mapping(address => RecoveryData) public recovery;

    function setTimestamp() external {
        recovery[msg.sender].lastActivity = uint128(block.timestamp);
    }
}
