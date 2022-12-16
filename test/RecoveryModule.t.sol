// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "safe-contracts/GnosisSafe.sol";
import "safe-contracts/common/Enum.sol";
import "safe-contracts/base/ModuleManager.sol";
import "./helpers/SafeDeployer.sol";
import {RecoveryModule} from "../src/RecoveryModule.sol";
import {Recovery} from "../src/Recovery.sol";
import {IRecovery} from "../src/IRecovery.sol";
import {IRecoveryModule} from "../src/IRecoveryModule.sol";

contract RecoveryModuleTest is SafeDeployer, Test {
    RecoveryModule public module;
    GnosisSafe public safe;
    Recovery public recovery;

    bytes private _validSignature = bytes(
        hex"0000000000000000000000007FA9385bE102ac3EAc297483Dd6233D62b3e14960000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    );

    function setUp() public {
        // Setup safe owners
        address[] memory owners = new address[](3);
        owners[0] = address(address(this));
        owners[1] = address(address(9999));
        owners[2] = address(address(8888));

        // Deploy safe
        safe = super.deploySafe({owners: owners, threshold: 1});

        recovery = new Recovery();

        // Deploy module
        module = new RecoveryModule(address(recovery));

        // Enable module on Safe
        // This assumes that threshold for safe will be 1, and that this contract is one of the safe owners
        safe.execTransaction({
            to: address(safe),
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

        assert(safe.isModuleEnabled(address(module)) == true);
    }

    function _initiateTransferOwnership() private {
        assert(recovery.getRecoveryAddress(address(safe)) == address(0));

        address recoveryAddress = address(1337);
        uint256 recoveryDate = block.timestamp + 365 days;

        // Add recovery address
        bool success = safe.execTransaction({
            to: address(recovery),
            value: 0,
            data: abi.encodeCall(IRecovery.addRecovery, (recoveryAddress, recoveryDate)),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: _validSignature
        });

        require(success, "tx failed");

        // Validate that recovery address and recovery date are set
        address safeAddress = address(safe);

        assert(recovery.getRecoveryAddress(safeAddress) == recoveryAddress);
        assert(recovery.getRecoveryDate(safeAddress) == recoveryDate);

        // fast forward blockchain so that we can call `initiateTransferOwnership` successfully
        vm.warp(recoveryDate);

        module.initiateTransferOwnership(safeAddress);

        // Assert that we have 10 day timelock on transfer ownership
        assert(module.getTimelockExpiration(safeAddress) == recoveryDate + 10 days);
    }

    function testInitiateTransferOwnership() external {
        _initiateTransferOwnership();
    }

    function testCancelTransferOwnership() external {
        _initiateTransferOwnership();

        // Safe can call `cancelTransferOwnership` on Recovery module to stop ownership transfer
        bool success = safe.execTransaction({
            to: address(module),
            value: 0,
            data: abi.encodeCall(IRecoveryModule.cancelTransferOwnership, ()),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: _validSignature
        });

        require(success, "tx failed");

        assert(module.getTimelockExpiration(address(safe)) == 0);
    }

    function testFinalizeTransferOwnership() external {
        _initiateTransferOwnership();

        // 10 days is timelock
        vm.warp(block.timestamp + 11 days);

        // 3 Owners before
        assert(safe.getOwners().length == 3);

        module.finalizeTransferOwnership(address(safe));

        // 1 owner after
        assert(safe.getOwners().length == 1);
    }
}
