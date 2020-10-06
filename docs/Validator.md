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


### `parseCheckpointOutputScript(bytes outputScript, bytes witnessScript) → bytes32 userBtc, bytes32 vaultBtc, uint256 timelock` (public)
Checks the validity of the transaction's output script, to ensure the locking conditions
are correct


### `checkRedeemTx(bytes btcLockingTx, uint64 outputIndex, bytes32 userBtcKey) → uint256` (public)



### `validateRecoverySig(bytes recSig, bytes32 userHashlock, bytes32 userBtc, bytes32 vaultBtc, bytes32 checkpointTxid)` (public)



### `quickParseCheckpointTx(bytes checkpointTransaction, uint256 numWitnessScripts, uint256 numRecSigs, uint256 numUsers) → bytes outputs, uint256 numOut` (public)



### `validateUserCheckpointValues(bytes outputs, uint256 i, bytes witnessScript, uint256 userBalance, bytes32 userBTC, bytes32 vaultBTC, uint256 requiredTimelock, uint256 timelockLeniency)` (public)
helper function in checkpoint validation



