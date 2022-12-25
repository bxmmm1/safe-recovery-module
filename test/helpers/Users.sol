// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

contract Users is Test {
    address internal constant _owner = address(1337);
    address internal constant _alice = address(52345345);
    address internal constant _bob = address(6435634534);
    address internal constant _charlie = address(33333333);

    constructor() {
        vm.label(_owner, "Owner");
        vm.label(_alice, "Alice");
        vm.label(_bob, "Bob");
        vm.label(_charlie, "Charlie");
    }
}
