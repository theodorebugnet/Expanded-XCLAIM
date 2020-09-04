//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.5.0 < 0.7.0;

import "@nomiclabs/buidler/console.sol";
import {Parser} from '@interlay/btc-relay-sol/contracts/Parser.sol';
import {BytesLib} from '@interlay/bitcoin-spv-sol/contracts/BytesLib.sol';

contract Validator {
    using BytesLib for bytes;

    /// Validates the issue transaction, ensuring the output script is valid and extracting the amount issued.
    /// @param btcLockingTx the full serialisation of the BTC transaction.
    /// @param witnessScript the script which matches the P2WSH output's hash in btcLockingTx
    /// @param outputIndex the exact output locking the backing coins for Issue
    /// @param userBtcKey the user's public key on the BTC chain
    /// @param vaultBtcKey the vault's public key on the BTC chain
    /// @param userLocktime the value that the timelock should have, based on the round length and user checkpoint frequency
    function checkIssueTx(
        bytes memory btcLockingTx,
        bytes memory witnessScript,
        uint64 outputIndex,
        bytes32 userBtcKey,
        bytes32 vaultBtcKey,
        uint userLocktime
    )
    public view
    returns (uint)
    {
        // get script and output's value
        (bytes memory script, uint val) = extractOutputInfo(btcLockingTx, outputIndex);

        // validate issue script
        require(checkpointOutputScriptValid(
            script, witnessScript, userBtcKey, vaultBtcKey, userLocktime),
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
    internal view
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
        bytes32 userBtc,
        bytes32 vaultBtc,
        uint userLocktime
    )
    internal view
    returns (bool)
    {
        // TODO - does the script hash from the output match the witness script? currently mock, assume correct

        //Script:
        // vaultBtc OP_CHECKSIGVERIFY userBtc OP_CHECKSIG OP_IFDUP OP_NOTIF
        //      userLocktime OP_CHECKSEQUENCEVERIFY
        // OP_ENDIF

        // vault pubkey push, 33 bytes
        require(uint8(witnessScript[0]) == 33, "Invalid vault public key length");
        // vault pubkey (ignore first checksum byte)
        require(witnessScript.slice(2, 32).toBytes32() == vaultBtc, "Incorrect vault public key");

        //OP_CHECKSIGVERIFY (0xad) followed by '33' (0x21) for the user pubkey push
        require(bytes2(witnessScript.slice(34, 2).toBytes32()) == 0xad21, "Invalid script");
        // user pubkey, ignoring first byte
        require(witnessScript.slice(37, 32).toBytes32() == userBtc, "Incorrect user public key");

        // OP_CHECKSIG (0xac) OP_IFDUP (0x73) OP_NOTIF (0x64)
        require(bytes3(witnessScript.slice(69, 3).toBytes32()) == 0xac7364, "Incorrect script");

        // length of timelock value push
        uint8 timelockLen = uint8(witnessScript[72]);
        // TODO - verify timelock according to BIP68 based on userLocktime - currently mock, assume correct

        // OP_CHECKSEQUENCEVERIFY (0xb2) OP_ENDIF (0x68)
        require(bytes2(witnessScript.slice(73 + timelockLen, 2).toBytes32()) == 0xb268, "Incorrect script");

        // everything passed
        return true;
    }

    function checkRedeemTx(
        bytes memory btcLockingTx,
        uint64 outputIndex,
        bytes32 userBtcKey
    )
    public view
    returns (uint)
    {
        (bytes memory script, uint val) = extractOutputInfo(btcLockingTx, outputIndex);
        // CURRENTLY MOCK
        // validate the p2wpk script to ensure output address == userBtcAddress
        return val;
    }
}
