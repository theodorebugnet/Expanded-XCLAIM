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
        // get script and output's value
        (bytes memory script, uint val) = extractOutputInfo(btcLockingTx, outputIndex);

        // validate issue script
        require(checkpointOutputScriptValid(
            script, witnessScript, userBtcAddress, vaultBtcAddress, userLocktime),
                "Submitted transaction output does not constitute a valid locking of backing funds.");

        //everything valid - return the value
        return val;
    }

    /// Helper method that extracts the script and the value of the output at the given index
    /// from the given transaction.
    function extractOutputInfo(
        bytes memory btcTx,
        uint64 outputIndex
    )
    internal pure
    returns (bytes memory script, uint outputValue)
    {
        //get the output
        (, uint lenIn) = Parser.extractInputLength(btcTx); //find start of outputs data
        bytes memory outputs = btcTx.slice(lenIn, btcTx.length - lenIn);
        bytes memory output = Parser.extractOutputAtIndex(outputs, outputIndex);

        script = Parser.extractOutputScript(output);
        outputValue = Parser.extractOutputValue(output);
    }

    /// Checks the validity of the transaction's output script, to ensure the locking conditions
    /// are correct
    function checkpointOutputScriptValid(
        bytes memory outputScript,
        bytes memory witnessScript,
        bytes20 userBtc,
        bytes20 vaultBtc,
        uint userLocktime
    )
    internal pure
    returns (bool)
    {
        // CURRENTLY MOCK

        //Script:
        // vaultBtc OP_CHECKSIGVERIFY userBtc OP_CHECKSIG OP_IFDUP OP_NOTIF
        //      userLocktime OP_CHECKSEQUENCEVERIFY
        // OP_ENDIF

        // does the script hash from the output match the witness script?
        // is the script of the right format? Get sigs and locktime.
        // does the locktime match the user's set frequency?
        // does the vault sig match the user's vault's btc address?
        // does the multisig match the user's and the vault's addresses?
        return true;
    }

    function checkRedeemTx(
        bytes memory btcLockingTx,
        uint64 outputIndex,
        bytes20 userBtcAddress
    )
    public pure
    returns (uint)
    {
        (bytes memory script, uint val) = extractOutputInfo(btcLockingTx, outputIndex);
        // CURRENTLY MOCK
        // validate the p2wpk script to ensure output address == userBtcAddress
        return val;
    }
}
