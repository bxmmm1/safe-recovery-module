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

        recovery.addRecovery{value: amount}(
            address(1337), uint64(block.timestamp) + 500 days, IRecovery.RecoveryType.After
        );

        assert(address(1337).balance == 0);

        recovery.withdrawFunds(amount, address(1337));

        assert(address(1337).balance == amount);
    }

    function testAddRecoveryShouldRevert() external {
        uint256 amount = 1337 ether;
        vm.expectRevert(abi.encodeWithSelector(IRecovery.InvalidPayment.selector, 0.1 ether));
        recovery.addRecovery{value: amount}(
            address(1337), uint64(block.timestamp) + 25 days, IRecovery.RecoveryType.After
        );
    }

    function testSetYearlySubscription(uint256 amount) external {
        recovery.setYearlySubscription(amount);
        assert(recovery.getYearlySubscription() == amount);
    }

    function testAddRecoveryModule() external {
        address module = address(555555);
        assert(recovery.isRecoveryModule(module) == false);
        recovery.addRecoveryModule(module);
        assert(recovery.isRecoveryModule(module) == true);
    }

    function testRemoveRecoveryModule() external {
        address module = address(555555);
        recovery.addRecoveryModule(module);
        assert(recovery.isRecoveryModule(module) == true);
        recovery.removeRecoveryModule(module);
        assert(recovery.isRecoveryModule(module) == false);
    }

    function testUpdateLastActivity() external {
        address module = address(555555);
        // whitelist module
        recovery.addRecoveryModule(module);
        vm.startBroadcast(module);

        address fakeSafe = address(12345);
        recovery.updateLastActivity(fakeSafe);
        assert(recovery.getLastActivity(fakeSafe) == block.timestamp);
        vm.stopBroadcast();
    }

    function testUpdateLastActivityShouldFail() external {
        address module = address(555555);
        // module is not whitelisted
        vm.startBroadcast(module);

        address fakeSafe = address(12345);
        vm.expectRevert(IRecovery.Unauthorized.selector);
        recovery.updateLastActivity(fakeSafe);
        vm.stopBroadcast();
        
        assert(recovery.getLastActivity(fakeSafe) == 0);
    }
}
