## `Validator`



### `checkIssueTx(bytes btcLockingTx, bytes witnessScript, uint64 outputIndex, bytes32 userBtcKey, bytes32 vaultBtcKey, uint256 userLocktime) → uint256` (public)
Validates the issue transaction, ensuring the output script is valid and extracting the amount issued.

#### Arguments:
* btcLockingTx: the full serialisation of the BTC transaction.
* witnessScript: the script which matches the P2WSH output's hash in btcLockingTx
* outputIndex: the exact output locking the backing coins for Issue
* userBtcKey: the user's public key on the BTC chain
* vaultBtcKey: the vault's public key on the BTC chain
* userLocktime: the value that the timelock should have, based on the round length and user checkpoint frequency

#### Returns:
* the: value of the output

### `parseCheckpointOutputScript(bytes outputScript, bytes witnessScript) → bytes32 userBtc, bytes32 vaultBtc, uint256 timelock` (public)
Checks the validity of the transaction's output script, to ensure the locking conditions
are correct, and returning the parameters used to lock the transaction. NOTE: scriptPubKey validation
is currently not implemented; only the (alleged) witnesscript is checked.

#### Arguments:
* outputScript: The P2WSH scriptPubKey of the transaction
* witnessScript: The witness script corresponding to the above P2WSH.

#### Returns:
* userBtc: The user's BTC pubkey from the script
* vaultBtc: The vault's BTC pubkey from the script
* timelock: The time the vault spending is locked for, from the script

### `checkRedeemTx(bytes btcLockingTx, uint64 outputIndex, bytes32 userBtcKey) → uint256` (public)
Validates the redeem transaction. Currently this is not fully implemented.
Should validate the P2WPK output to ensure it corresponds to the user's BTC key.

#### Arguments:
* btcLockingTx: The serialised transaction
* outputIndex: The output corresponding to the payout to the user
* userBtcKey: The BTC key of the user that the output should pay out to, to be valid.

#### Returns:
* The: value of the output (if it was correct).

### `validateRecoverySig(bytes recSig, bytes32 userHashlock, bytes32 userBtc, bytes32 vaultBtc, bytes32 checkpointTxid)` (public)
Validates the signature for a recovery transaction by the vault.
The recovery transaction is constructed using the known values for the user keys
and haslocks etc., then the provided signature is checked against it.
This is currently mock, and not implemented.

#### Arguments:
* recSig: the signature data
* userHashlock: the hashlock set by the user for the recovery HTLC
* userBtc: the user's BTC pubkey
* vaultBtc: the vault's BTC pubkey
* checkpointTxid: the TXID of the checkpoint transaction the user last participated in (to construct the input)


### `quickParseCheckpointTx(bytes checkpointTransaction, uint256 numWitnessScripts, uint256 numRecSigs, uint256 numUsers) → bytes outputs, uint256 numOut` (public)
Helper function that extracts the outputs from a checkpoint transaction.

#### Arguments:
* checkpointTransaction: the serialised transaction
* numWitnessScripts: the number of witness scripts passed to the checkpoint validation (to assert they're equal to the number of outputs)
* numRecSigs: the number of recovery transaction signatures passed to checkpoint validation (as above)
* numUsers: the number of users the checkpoint is specified to have (as above)

#### Returns:
* outputs: the serialised transaction outputs
* numOut: the number of outputs (which should be equal to numUsers etc.)

### `validateUserCheckpointValues(bytes outputs, uint256 i, bytes witnessScript, uint256 userBalance, bytes32 userBTC, bytes32 vaultBTC, uint256 requiredTimelock, uint256 timelockLeniency)` (public)
Helper function in checkpoint validation, containing checks for a variety of values.

#### Arguments:
* outputs: the serialised outputs of the checkpoint
* i: the index of the output being checked
* witnessScript: the witness script corresponding to the P2WSH output
* userBalance: the user's token balance (to validate the checkpoint output value)
* userBTC: the user's BTC pubkey
* vaultBTC: the vault's BTC pubkey
* requiredTimelock: the timelock value expected in the checkpoint for this user
* timelockLeniency: the allowed deviation in timelock duration



