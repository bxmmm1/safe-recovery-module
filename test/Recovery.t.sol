// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./helpers/SafeDeployer.sol";
import {Recovery, IRecovery} from "../src/Recovery.sol";
import {Users} from "./helpers/Users.sol";

contract RecoveryModuleTest is SafeDeployer, Users {
    Recovery public recovery;
    GnosisSafe public safeContract;
    address public safe;

    function setUp() public {
        recovery = new Recovery();
        vm.label(address(recovery), "Recovery");
        _deploySafe();
    }

    function _deploySafe() private {
        address[] memory owners = new address[](3);
        owners[0] = _alice;
        owners[1] = _bob;
        owners[2] = _charlie;

        // Deploy safe
        safeContract = super.deploySafe({owners: owners, threshold: 1});
        safe = address(safe);
        vm.label(safe, "Safe");

        vm.deal(safe, 1 ether);
    }

    function testAddRecovery() external {
        uint256 amount = 0.2 ether;

        vm.prank(safe);

        recovery.addRecoveryWithSubscription{value: amount}(
            _alice, uint64(block.timestamp) + 500 days, IRecovery.RecoveryType.After
        );

        assert(_alice.balance == 0);

        recovery.withdrawFunds(amount, _alice);

        assert(_alice.balance == amount);
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
            _alice, uint64(block.timestamp) + 25 days, IRecovery.RecoveryType.After
        );
    }

    function testAddRecoveryWithoutSubscription() external {
        address recoveryAddress = address(1337);
        uint64 recoveryDate = uint64(block.timestamp) + 500 days;

        vm.prank(safe);
        recovery.addRecovery(recoveryAddress, recoveryDate, IRecovery.RecoveryType.After);

        assert(recovery.getRecoveryAddress(safe) == recoveryAddress);
        assert(recovery.getRecoveryDate(safe) == uint256(recoveryDate));
        assert(recovery.getRecoveryType(safe) == IRecovery.RecoveryType.After);
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
