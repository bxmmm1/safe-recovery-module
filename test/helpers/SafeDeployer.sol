// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "safe-contracts/GnosisSafe.sol";
import "safe-contracts/proxies/GnosisSafeProxy.sol";

contract SafeDeployer {
    GnosisSafe private _safeSingleton;

    constructor() {
        _safeSingleton = new GnosisSafe();
    }

    /// @notice Deploys Gnosis safe
    /// @param owners are safe owners
    /// @param threshold of owners needed to sign the transaction
    /// @return GnosisSafe
    function deploySafe(address[] memory owners, uint256 threshold) internal returns (GnosisSafe) {
        require(owners.length >= threshold, "number of owners should be >= threshold");
        GnosisSafeProxy proxy = new GnosisSafeProxy(address(_safeSingleton));

        GnosisSafe safe = GnosisSafe(payable(address(proxy)));

        safe.setup({
            _owners: owners,
            _threshold: threshold,
            to: address(0),
            data: "",
            fallbackHandler: address(0),
            paymentToken: address(0),
            payment: 0,
            paymentReceiver: payable(address(0))
        });

        return safe;
    }
}
