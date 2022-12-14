// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "safe-contracts/GnosisSafe.sol";
import "safe-contracts/common/Enum.sol";
import "safe-contracts/base/OwnerManager.sol";

contract ExampleModule {
    address internal constant SENTINEL_OWNERS = address(0x1);

    function swapOwner(GnosisSafe safe, address newOwner) external {
        address oldOwner = safe.getOwners()[0];

        bytes memory data = abi.encodeCall(OwnerManager.swapOwner, (SENTINEL_OWNERS, oldOwner, newOwner));

        bool success =
            safe.execTransactionFromModule({to: address(safe), value: 0, data: data, operation: Enum.Operation.Call});

        require(success, "transaction failed");
    }
}
