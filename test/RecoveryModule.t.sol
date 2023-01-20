// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {GnosisSafe, GuardManager, Enum, ModuleManager} from "safe-contracts/GnosisSafe.sol";
import {SafeDeployer} from "./helpers/SafeDeployer.sol";
import {RecoveryModule, IRecoveryModule} from "../src/RecoveryModule.sol";
import {Users} from "./helpers/Users.sol";

contract RecoveryModuleTest is SafeDeployer, Users {
    RecoveryModule public module;
    GnosisSafe public safeContract;
    address public safe;

    uint256 private _timelock = 10 days;

    // Because this smart contract is the safe owner, we can hardcode signature
    // 0xFA9385bE102ac3EAc297483Dd6233D62b3e1496 is address(this)
    bytes private _validSignature = bytes(
        hex"0000000000000000000000007FA9385bE102ac3EAc297483Dd6233D62b3e14960000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    );

    function setUp() public {
        // Setup safe owners
        address[] memory owners = new address[](3);
        owners[0] = address(this);
        owners[1] = _alice;
        owners[2] = _bob;

        // Deploy safe
        safeContract = super.deploySafe({owners: owners, threshold: 1});
        safe = address(safeContract);
        vm.label(safe, "Safe");

        // Deploy module
        module = new RecoveryModule(_timelock);
        vm.label(address(module), "RecoveryModule");

        vm.deal(safe, 100 ether);

        // Enable module on Safe
        // This assumes that threshold for safe will be 1, and that this contract is one of the safe owners
        safeContract.execTransaction({
            to: safe,
            value: 0,
            data: abi.encodeCall(ModuleManager.enableModule, (address(module))),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: _validSignature
        });

        // Set guard on Safe
        // We do this so that we can have on chain record of latest safe's tx timestamp
        safeContract.execTransaction({
            to: safe,
            value: 0,
            data: abi.encodeCall(GuardManager.setGuard, (address(module))),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: _validSignature
        });
    }

    function testSetUp() external view {
        require(safeContract.isModuleEnabled(address(module)) == true);
    }

    function _initiateTransferOwnership() private {
        require(module.getRecoveryAddress(safe) == address(0));

        address recoveryAddress = address(1337);
        uint40 recoveryDate = uint40(block.timestamp) + 25 days;

        // subscription for 1 year
        bool success = _addRecoveryAfter(recoveryAddress, recoveryDate, 3 ether);

        require(success, "tx failed");

        // Validate that recovery address and recovery date are set
        address safeAddress = safe;

        require(module.getRecoveryAddress(safeAddress) == recoveryAddress);
        require(module.getRecoveryDate(safeAddress) == recoveryDate);

        // fast forward blockchain so that we can call `initiateTransferOwnership` successfully
        vm.warp(recoveryDate);

        module.initiateTransferOwnership(safeAddress);

        // require that we have 10 day timelock on transfer ownership
        require(module.getTimelockExpiration(safeAddress) == recoveryDate + 10 days);
    }

    function testInitiateTransferOwnership() external {
        _initiateTransferOwnership();
    }

    function testAddRecoveryShouldRevertForBadRecoveryAddress() external {
        vm.expectRevert("GS013"); // GS013 is Safe error
        _addRecoveryAfter(address(0), uint40(block.timestamp + 25 days), 1 ether);
    }

    function testCancelTransferOwnership() external {
        _initiateTransferOwnership();

        // Safe can call `cancelTransferOwnership` on Recovery module to stop ownership transfer
        bool success = safeContract.execTransaction({
            to: address(module),
            value: 0,
            data: abi.encodeCall(IRecoveryModule.clearRecovery, ()),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: _validSignature
        });

        require(success, "tx failed");

        require(module.getTimelockExpiration(safe) == 0);
    }

    /// Finalize transfer ownership should work
    function testFinalizeTransferOwnership() external {
        _initiateTransferOwnership();

        // 10 days is timelock
        vm.warp(block.timestamp + 11 days);

        // 3 Owners before
        require(safeContract.getOwners().length == 3);

        vm.broadcast(_charlie);

        module.finalizeTransferOwnership(safe);

        // 1 owner after
        require(safeContract.getOwners().length == 1);
    }

    function testFailFinalizeOwnership() external {
        module.finalizeTransferOwnership(safe);
    }

    // If we did not initialize transfer ownership, and we try to finalize
    // it should revert
    function testFinalizeTransferOwnershipShouldRevert() external {
        vm.expectRevert(IRecoveryModule.InvalidAddress.selector);
        module.finalizeTransferOwnership(safe);
    }

    function testInitiateTransferOwnershipShouldRevertWithInvalidAddress() external {
        vm.expectRevert(IRecoveryModule.InvalidAddress.selector);
        module.initiateTransferOwnership(safe);
    }

    function testInitiateTransferOwnershipTooEarlyShouldRevert() external {
        address recoveryAddress = address(1337);
        uint40 recoveryDate = uint40(block.timestamp) + 25 days;

        _addRecoveryAfter(recoveryAddress, recoveryDate, 1 ether);

        vm.expectRevert(IRecoveryModule.TooEarly.selector);
        module.initiateTransferOwnership(safe);
    }

    function testInitiateFinalizeTooEarlyShouldRevert() external {
        address recoveryAddress = address(1337);
        uint40 recoveryDate = uint40(block.timestamp) + 25 days;

        _addRecoveryAfter(recoveryAddress, recoveryDate, 2 ether);

        vm.warp(recoveryDate);

        // Initiate transfer ownership
        module.initiateTransferOwnership(safe);

        // Try to finalize right away
        vm.expectRevert(IRecoveryModule.TooEarly.selector);
        module.finalizeTransferOwnership(safe);
    }

    function testInitiateTransferOwnershipShouldRevertWithAlreadyInitiated() external {
        _initiateTransferOwnership();
        vm.expectRevert(IRecoveryModule.TransferOwnershipAlreadyInitiated.selector);
        module.initiateTransferOwnership(safe);
    }

    function testDuplicateAddRecoveryShouldWork() external {
        uint40 recoveryDate = uint40(block.timestamp) + 25 days;

        uint256 amount1 = 1 ether;
        uint256 amount2 = 5 ether;

        // Add recovery address
        bool success = safeContract.execTransaction({
            to: address(module),
            value: amount1,
            data: abi.encodeCall(IRecoveryModule.addRecovery, (_charlie, recoveryDate, IRecoveryModule.RecoveryType.After)),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: _validSignature
        });

        require(success);

        // Add recovery address
        success = safeContract.execTransaction({
            to: address(module),
            value: amount2,
            data: abi.encodeCall(IRecoveryModule.addRecovery, (_charlie, recoveryDate, IRecoveryModule.RecoveryType.After)),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: _validSignature
        });

        require(success);
        require(module.getRecoveryValue(address(safeContract)) == (amount1 + amount2), "amounts don't match");
    }

    function testInactiveForShouldWork(address recoveryAddress, uint40 inactivityInSeconds, uint256 recoveryValue)
        external
    {
        vm.assume(recoveryAddress != address(0));
        vm.assume(recoveryAddress != address(1)); // sentinel modules address
        vm.assume(recoveryAddress != address(safe));
        vm.assume(recoveryValue < address(safe).balance);
        vm.assume(inactivityInSeconds != 0);
        vm.label(recoveryAddress, "Recovery address");

        bool success = _addRecoveryInactiveFor(recoveryAddress, inactivityInSeconds, recoveryValue);

        require(success);

        vm.warp(block.timestamp + inactivityInSeconds);

        module.initiateTransferOwnership(safe);

        vm.warp(block.timestamp + _timelock + 1);

        vm.broadcast(_greg);

        module.finalizeTransferOwnership(safe);
    }

    function testInactiveForTooEarlyShouldRevert(uint40 timestamp) external {
        vm.assume(timestamp > block.timestamp);

        address recoveryAddress = address(1337);

        bool success = _addRecoveryInactiveFor(recoveryAddress, timestamp, 1 ether);

        require(success);

        // no fast forward
        vm.expectRevert(IRecoveryModule.TooEarly.selector);

        module.initiateTransferOwnership(safe);
    }

    function _addRecoveryAfter(address recoveryAddress, uint40 recoveryDate, uint256 subscriptionAmount)
        private
        returns (bool)
    {
        // Add recovery address
        bool success = safeContract.execTransaction({
            to: address(module),
            value: subscriptionAmount,
            data: abi.encodeCall(
                IRecoveryModule.addRecovery, (recoveryAddress, recoveryDate, IRecoveryModule.RecoveryType.After)
                ),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: _validSignature
        });

        return success;
    }

    function _addRecoveryInactiveFor(address recoveryAddress, uint40 recoveryDate, uint256 recoveryValue)
        private
        returns (bool)
    {
        // Add recovery address
        bool success = safeContract.execTransaction({
            to: address(module),
            value: recoveryValue,
            data: abi.encodeCall(
                IRecoveryModule.addRecovery, (recoveryAddress, recoveryDate, IRecoveryModule.RecoveryType.InactiveFor)
                ),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: _validSignature
        });

        return success;
    }
}
