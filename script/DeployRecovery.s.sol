// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/RecoveryModule.sol";

contract DeployRecovery is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PK");
        vm.startBroadcast(deployerPrivateKey);

        RecoveryModule module = new RecoveryModule(10 minutes);

        console2.log("Safe module deployed:", address(module));

        vm.stopBroadcast();
    }
}
