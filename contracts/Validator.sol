//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.5.0 < 0.7.0;

import {Parser} from '@interlay/btc-relay-sol/contracts/Parser.sol';
import {BytesLib} from '@interlay/bitcoin-spv-sol/contracts/BytesLib.sol';

contract Validator {
    using BytesLib for bytes;

    /// Validates the issue transaction, ensuring the output script is valid and extracting the amount issued.
    /// @param btcLockingTx the full serialisation of the BTC transaction.
    /// @param witnessScript the script which matches the P2WSH output's hash in btcLockingTx
    /// @param outputIndex the exact output locking the backing coins for Issue
    /// @param userBtcAddress the user's address on the BTC chain
    /// @param vaultBtcAddress the vault's address on the BTC chain
    /// @param userLocktime the value that the timelock should have, based on the round length and user checkpoint frequency
    function checkIssueTx(
        bytes memory btcLockingTx,
        bytes memory witnessScript,
        uint64 outputIndex,
        bytes20 userBtcAddress,
        bytes20 vaultBtcAddress,
        uint userLocktime
    )
    public pure
    returns (uint)
    {
        //get the output
        (, uint lenIn) = Parser.extractInputLength(btcLockingTx); //find start of outputs data
        bytes memory outputs = btcLockingTx.slice(lenIn, btcLockingTx.length - lenIn);
        bytes memory output = Parser.extractOutputAtIndex(outputs, outputIndex);

        //is script valid?
        bytes memory script = Parser.extractOutputScript(output);
        require(checkpointOutputScriptValid(
            script, witnessScript, userBtcAddress, vaultBtcAddress, userLocktime),
                "Submitted transaction output does not constitute a valid locking of backing funds.");

        //everything valid so far, get output value and return
        return Parser.extractOutputValue(output);
    }

    /// Checks the validity of the transaction's output script, to ensure the locking conditions
    /// are correct
    function checkpointOutputScriptValid(bytes memory outputScript, bytes memory witnessScript, bytes20 userBtc, bytes20 vaultBtc, uint userLocktime)
    internal pure
    returns (bool)
    {
        // CURRENTLY MOCK

        // does the script hash from the output match the witness script?
        // is the script of the right format? Get sigs and locktime.
        // does the locktime match the user's set frequency?
        // does the vault sig match the user's vault's btc address?
        // does the multisig match the user's and the vault's addresses?
        return true;
    }

    function checkpointRecoveryValid()
    public pure
    returns (bool)
    {
        // TODO

        // 
        return true;
    }
}
