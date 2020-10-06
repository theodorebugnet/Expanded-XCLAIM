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
    /// @return the value of the output
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
        //get the output
        (, uint lenIn) = Parser.extractInputLength(btcLockingTx); //find start of outputs data
        bytes memory outputs = btcLockingTx.slice(lenIn, btcLockingTx.length - lenIn);
        bytes memory output = Parser.extractOutputAtIndex(outputs, outputIndex);
        
        // get script and output's value
        bytes memory script = Parser.extractOutputScript(output);
        uint val = Parser.extractOutputValue(output);

        // parse issue script
        (bytes32 allegedUserBTC, bytes32 allegedVaultBTC, uint allegedTimelock) =
            parseCheckpointOutputScript(script, witnessScript);

        require(allegedUserBTC == userBtcKey, "Invalid user public key.");
        require(allegedVaultBTC == vaultBtcKey, "Invalid vault public key.");
        // TODO - verify timelock according to BIP68 based on userLocktime - currently mock, assume correct

        //everything valid - return the value
        return val;
    }

    /// Checks the validity of the transaction's output script, to ensure the locking conditions
    /// are correct, and returning the parameters used to lock the transaction. NOTE: scriptPubKey validation
    /// is currently not implemented; only the (alleged) witnesscript is checked.
    /// @param outputScript The P2WSH scriptPubKey of the transaction
    /// @param witnessScript The witness script corresponding to the above P2WSH.
    /// @return userBtc The user's BTC pubkey from the script
    /// @return vaultBtc The vault's BTC pubkey from the script
    /// @return timelock The time the vault spending is locked for, from the script
    function parseCheckpointOutputScript(
        bytes memory outputScript,
        bytes memory witnessScript
    )
    public view
    returns (
        bytes32 userBtc,
        bytes32 vaultBtc,
        uint timelock
    )
    {
        // TODO - does the script hash from the output match the witness script? currently mock, assumes correct

        //Script:
        // vaultBtc OP_CHECKSIGVERIFY userBtc OP_CHECKSIG OP_IFDUP OP_NOTIF
        //      userLocktime OP_CHECKSEQUENCEVERIFY
        // OP_ENDIF

        // vault pubkey push, 33 bytes
        require(uint8(witnessScript[0]) == 33, "Invalid vault public key length");
        // get alleged vault pubkey
        vaultBtc = witnessScript.slice(2, 32).toBytes32();

        //OP_CHECKSIGVERIFY (0xad) followed by '33' (0x21) for the user pubkey push
        require(bytes2(witnessScript.slice(34, 2).toBytes32()) == 0xad21, "Invalid script");
        // get alleged user pubkey
        userBtc = witnessScript.slice(37, 32).toBytes32();

        // OP_CHECKSIG (0xac) OP_IFDUP (0x73) OP_NOTIF (0x64)
        require(bytes3(witnessScript.slice(69, 3).toBytes32()) == 0xac7364, "Incorrect script");

        // length of timelock value push
        uint8 timelockLen = uint8(witnessScript[72]);
        // now make a left-padded int with the timelock value:
        bytes32 timelockBytes = witnessScript.slice(73, witnessScript.length - 73).toBytes32();
        timelockBytes = timelockBytes >> (256 - 8 * timelockLen);
        timelock = uint256(timelockBytes);

        // OP_CHECKSEQUENCEVERIFY (0xb2) OP_ENDIF (0x68)
        require(bytes2(witnessScript.slice(73 + timelockLen, 2).toBytes32()) == 0xb268, "Incorrect script");
    }

    /// Validates the redeem transaction. Currently this is not fully implemented.
    /// Should validate the P2WPK output to ensure it corresponds to the user's BTC key.
    /// @param btcLockingTx The serialised transaction
    /// @param outputIndex The output corresponding to the payout to the user
    /// @param userBtcKey The BTC key of the user that the output should pay out to, to be valid.
    /// @return The value of the output (if it was correct).
    function checkRedeemTx(
        bytes memory btcLockingTx,
        uint64 outputIndex,
        bytes32 userBtcKey
    )
    public view
    returns (uint)
    {
        // get output
        (, uint lenIn) = Parser.extractInputLength(btcLockingTx); //find start of outputs data
        bytes memory outputs = btcLockingTx.slice(lenIn, btcLockingTx.length - lenIn);
        bytes memory output = Parser.extractOutputAtIndex(outputs, outputIndex);
        
        // get script and output's value
        bytes memory script = Parser.extractOutputScript(output);
        uint val = Parser.extractOutputValue(output);

        // CURRENTLY MOCK
        // validate the p2wpk script to ensure output address == userBtcAddress
        return val;
    }

    /// Validates the signature for a recovery transaction by the vault.
    /// The recovery transaction is constructed using the known values for the user keys
    /// and haslocks etc., then the provided signature is checked against it.
    /// This is currently mock, and not implemented.
    /// @param recSig the signature data
    /// @param userHashlock the hashlock set by the user for the recovery HTLC
    /// @param userBtc the user's BTC pubkey
    /// @param vaultBtc the vault's BTC pubkey
    /// @param checkpointTxid the TXID of the checkpoint transaction the user last participated in (to construct the input)
    function validateRecoverySig(
        bytes memory recSig,
        bytes32 userHashlock,
        bytes32 userBtc,
        bytes32 vaultBtc,
        bytes32 checkpointTxid
    )
    public view
    {
        // TODO - MOCK
        // 1. construct recoveryTx
        // 1.1. spend from checkpointTxid, using known witnessScript
        // 1.2. construct standard recovery output - timed hashlock
        // 2. implement signature algorithm to check whether recSig is a valid signature for either of the vault or user pubkeys
        // revert if verification fails
    }

    /// Helper function that extracts the outputs from a checkpoint transaction.
    /// @param checkpointTransaction the serialised transaction
    /// @param numWitnessScripts the number of witness scripts passed to the checkpoint validation (to assert they're equal to the number of outputs)
    /// @param numRecSigs the number of recovery transaction signatures passed to checkpoint validation (as above)
    /// @param numUsers the number of users the checkpoint is specified to have (as above)
    /// @return outputs the serialised transaction outputs
    /// @return numOut the number of outputs (which should be equal to numUsers etc.)
    function quickParseCheckpointTx(
        bytes memory checkpointTransaction,
        uint numWitnessScripts,
        uint numRecSigs,
        uint numUsers
    )
    public view
    returns (bytes memory outputs, uint numOut)
    {
        // get outputs
        (, uint lenIn) = Parser.extractInputLength(checkpointTransaction); //find start of outputs data
        outputs = checkpointTransaction.slice(lenIn, checkpointTransaction.length - lenIn);
        (numOut, ) = Parser.extractOutputLength(outputs);
        require(numWitnessScripts == numOut, "Number of witness scripts does not match number of transaction outputs");
        require(numRecSigs == numOut, "Number of recovery signatures does not match number of transaction outputs");
        require(numUsers == numOut, "Number of users does not match number of transaction outputs");
    }


    /// Helper function in checkpoint validation, containing checks for a variety of values.
    /// @param outputs the serialised outputs of the checkpoint
    /// @param i the index of the output being checked
    /// @param witnessScript the witness script corresponding to the P2WSH output
    /// @param userBalance the user's token balance (to validate the checkpoint output value)
    /// @param userBTC the user's BTC pubkey
    /// @param vaultBTC the vault's BTC pubkey
    /// @param requiredTimelock the timelock value expected in the checkpoint for this user
    /// @param timelockLeniency the allowed deviation in timelock duration
    function validateUserCheckpointValues(
        bytes memory outputs,
        uint i,
        bytes memory witnessScript,
        uint userBalance,
        bytes32 userBTC,
        bytes32 vaultBTC,
        uint requiredTimelock,
        uint timelockLeniency
    )
    public view
    {
        //TODO: refactor this, as part of checkpoint validation refactor

        // get output itself, and verify value
        bytes memory output = Parser.extractOutputAtIndex(outputs, i);

        //validate value
        require(Parser.extractOutputValue(output) == userBalance, "Incorrect checkpoint output value");

        // call validator to verify output script, get back user, timelock, value
        (bytes32 allegedUserBTC, bytes32 allegedVaultBTC, uint allegedTimelock) =
            parseCheckpointOutputScript(Parser.extractOutputScript(output), witnessScript);

        // validate user key, vault key, and timelock
        require(allegedUserBTC == userBTC, "Invalid user BTC key");
        require(allegedVaultBTC == vaultBTC, "Invalid vault");
        require(allegedTimelock <= requiredTimelock + timelockLeniency, "Timelock incorrect - too high");
        require(allegedTimelock >= requiredTimelock - timelockLeniency, "Timelock incorrect - too low");
    }
}
