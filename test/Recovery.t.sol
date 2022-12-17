// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {IRecovery} from "..//src/IRecovery.sol";
import {Recovery} from "../src/Recovery.sol";

contract RecoveryModuleTest is Test {
    Recovery public recovery;

    function setUp() public {
        recovery = new Recovery();
    }

    function testAddRecovery() external {
        uint256 amount = 0.2 ether;

        recovery.addRecovery{value: amount}(address(1337), uint64(block.timestamp) + 500 days);

        assert(address(1337).balance == 0);

        recovery.withdrawFunds(amount, address(1337));

        assert(address(1337).balance == amount);
    }

    function testAddRecoveryShouldRevert() external {
        uint256 amount = 1337 ether;
        vm.expectRevert(abi.encodeWithSelector(IRecovery.InvalidPayment.selector, 0.1 ether));
        recovery.addRecovery{value: amount}(address(1337), uint64(block.timestamp) + 25 days);
    }

    function testSetYearlySubscription(uint256 amount) external {
        recovery.setYearlySubscription(amount);
        assert(recovery.getYearlySubscription() == amount);
    }
}
