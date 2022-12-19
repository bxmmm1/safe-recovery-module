// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "./helpers/SafeDeployer.sol";

import {IRecovery} from "..//src/IRecovery.sol";
import {Recovery} from "../src/Recovery.sol";

contract RecoveryModuleTest is SafeDeployer, Test {
    Recovery public recovery;
    GnosisSafe public safe;

    function setUp() public {
        recovery = new Recovery();
        _deploySafe();
    }

    function _deploySafe() private {
        address[] memory owners = new address[](3);
        owners[0] = address(55);
        owners[1] = address(56);
        owners[2] = address(57);

        // Deploy safe
        safe = super.deploySafe({owners: owners, threshold: 1});

        vm.deal(address(safe), 1 ether);
    }

    function testAddRecovery() external {
        uint256 amount = 0.2 ether;

        vm.prank(address(safe));
        recovery.addRecoveryWithSubscription{value: amount}(
            address(1337), uint64(block.timestamp) + 500 days, IRecovery.RecoveryType.After
        );

        assert(address(1337).balance == 0);

        recovery.withdrawFunds(amount, address(1337));

        assert(address(1337).balance == amount);
    }

    function testAddRecoveryShouldRevertOnInvalidAddress() external {
        vm.expectRevert(abi.encodeWithSelector(IRecovery.InvalidRecoveryAddress.selector));
        recovery.addRecoveryWithSubscription{value: 0.1 ether}(
            address(0), uint64(block.timestamp) + 25 days, IRecovery.RecoveryType.After
        );

        vm.expectRevert(abi.encodeWithSelector(IRecovery.InvalidRecoveryAddress.selector));
        recovery.addRecovery(address(0), uint64(block.timestamp) + 25 days, IRecovery.RecoveryType.After);
    }

    function testAddRecoveryShouldRevert() external {
        uint256 amount = 1337 ether;
        vm.expectRevert(abi.encodeWithSelector(IRecovery.InvalidPayment.selector, 0.1 ether));
        recovery.addRecoveryWithSubscription{value: amount}(
            address(1337), uint64(block.timestamp) + 25 days, IRecovery.RecoveryType.After
        );
    }

    function testAddRecoveryWithoutSubscription() external {
        address recoveryAddress = address(1337);
        uint64 recoveryDate = uint64(block.timestamp) + 500 days;

        vm.prank(address(safe));
        recovery.addRecovery(recoveryAddress, recoveryDate, IRecovery.RecoveryType.After);

        assert(recovery.getRecoveryAddress(address(safe)) == recoveryAddress);
        assert(recovery.getRecoveryDate(address(safe)) == uint256(recoveryDate));
        assert(recovery.getRecoveryType(address(safe)) == IRecovery.RecoveryType.After);
    }

    function testSubscriptionAmount(uint256 amount) external {
        recovery.setSubscription(amount);
        assert(recovery.getSubscriptionAmount() == amount);
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
