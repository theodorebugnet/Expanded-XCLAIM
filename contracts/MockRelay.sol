//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.5.0 < 0.7.0;

contract Relay {
    /// Mock of the transaction inclusion function from BTCRelay, for development.
    /// Reproduces the BTCRelay interface, but always returns true.
    /// See BTCRelay for parameters.
    function verifyTx(
        uint32 height,
        uint256 index,
        bytes32 txid,
        bytes calldata header,
        bytes calldata proof,
        uint256 confirmations,
        bool insecure
    )
    external pure
    returns (bool)
    {
        return true;
    }
}
