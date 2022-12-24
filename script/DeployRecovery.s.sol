// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Recovery.sol";
import "../src/RecoveryModule.sol";

contract DeployRecovery is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PK");
        vm.startBroadcast(deployerPrivateKey);

        Recovery recovery = new Recovery();
        RecoveryModule module = new RecoveryModule(address(recovery), 10 minutes);

        console2.log("Recovery deployed:", address(recovery));
        console2.log("Safe module deployed:", address(module));

        vm.stopBroadcast();
    }
}
