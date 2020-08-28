## `Validator`



### `checkIssueTx(bytes btcLockingTx, bytes witnessScript, uint64 outputIndex, bytes20 userBtcAddress, bytes20 vaultBtcAddress, uint256 userLocktime) → uint256` (public)
Validates the issue transaction, ensuring the output script is valid and extracting the amount issued.

####Arguments:
* btcLockingTx: the full serialisation of the BTC transaction.
* witnessScript: the script which matches the P2WSH output's hash in btcLockingTx
* outputIndex: the exact output locking the backing coins for Issue
* userBtcAddress: the user's address on the BTC chain
* vaultBtcAddress: the vault's address on the BTC chain
* userLocktime: the value that the timelock should have, based on the round length and user checkpoint frequency


### `extractOutputInfo(bytes btcTx, uint64 outputIndex) → bytes script, uint256 outputValue` (internal)
Helper method that extracts the script and the value of the output at the given index
from the given transaction.


### `checkpointOutputScriptValid(bytes outputScript, bytes witnessScript, bytes20 userBtc, bytes20 vaultBtc, uint256 userLocktime) → bool` (internal)
Checks the validity of the transaction's output script, to ensure the locking conditions
are correct


### `checkRedeemTx(bytes btcLockingTx, uint64 outputIndex, bytes20 userBtcAddress) → uint256` (public)




