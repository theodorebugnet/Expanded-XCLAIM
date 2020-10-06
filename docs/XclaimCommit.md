## `XclaimCommit`


### `vaultHasUser(address vault, address user)`
When a vault performs an operation on a user, revert unless the user is registered with that vault.

### `vaultExists(address vault)`
Revert if an address does not match any registered vault.

### `userNotDueForCheckpoint(address user)`
Checks whether the user is able to carry out normal operations, e.g. trading,
which are suspended when a round is over until the round's checkpoint is verified.
Users are of course only affected by rounds where they are scheduled for a checkpoint.

### `roundScheduler()`
Increments round if previous round length has been exceeded.
Due to ETH block times, rounds will vary +=10s to a minute, so rounds should
be long enough for this to not matter. Frequent rounds give more flexibility
for scheduling users, but are otherwise not necessary. ~1h per round is reasonable.


### `constructor(address relayAddr, address exchangeOracleAddr, address validatorAddr)` (public)
Initialises values, and sets addresses for auxilliary contracts


### `registerUser(bytes32 btcKey, address vaultaddr, uint16 frequency, bytes32[] hashes)` (public)
Creates a new user, registered to a given vault (which must exist), and optionally sets
hashes to use for future hashlocks

**Called by:** the user registering


### `updateHashlist(bytes32[] hashes, uint256[] checkpoints)` (public)
Updates the future hashes saved for the user, which can both add to the existing list
or overwrite already set ones (e.g. if the user loses their preimages)

*Called by:** the user updating their hashes

#### Arguments:
* hashes: a list of hashes to save
* checkpoints: a list of checkpoint indices, corresponding 1:1 to the element hash at the same array location. They denote a user's checkpoint counter (with user.checkpointIndex being the next one that will be used).


### `updateFrequency(uint16 newFreq)` (public)
Allows the user to change their checkpoint frequency. Does not validate with
the vault - negotiations will happen off-chain (the vault can always refuse service
in the event of a dispute).

**Called by:** the user


### `registerVault(bytes32 btcKey)` (public)
Registers a vault with the given BTC address. No commitment is required; to
provide a useful list of vaults, interfaces may wish to sort by e.g. amount
of collateral available in the vault's pool.

*Called by:** the vault


### `topUpCollateralPool()` (public)
Allows the vault to deposit funds that can be used to collateralise
(but which are not yet locked)

*Called by:** the vault


### `drainCollateralPool(uint256 amount)` (public)
Allows the vault to withdraw unlocked collateral funds

*Called by:** the vault


### `lockCollateral(address user, uint256 amount)` (public)
Locks a specified amount of collateral against a user. Collateral is specified
in ETH (while the tokens are in BTC), hence the exchange rate oracle is used
(the oracle is also responsible for any overcollateralisation which may be
necessary over the short time a user is expected to be collateralised).

*Called by:** the vault


### `releaseCollateral(address vault, address user, uint256 amount)` (internal)
Helper function used to unlock vault collateral locked against a user.


### `burnTokens(uint256 btcAmount) → uint256` (public)
Destroys the amount of tokens requested by the users.
User must then proceed with the appropriate steps to redeem or recover
their backing funds.

*Called by:** the user

#### Returns:
* the: ID of this redeem request (to be used later to release vault collateral or reimburse the user)

### `reimburse(address user, uint256 btcAmount)` (internal)
Helper function which slashes vault collateral and provides it to the user,
burning a corresponding amount of user tokens.


### `transfer(address recipient, uint256 amount)` (public)



### `issueTokens(bytes btcLockingTx, bytes witnessScript, uint64 outputIndex, uint32 blockHeight, uint256 txIndex, bytes blockHeader, bytes merkleProof)` (public)
Given a valid Issue transaction on BTC, credits the user with the corresponding amount
of backed tokens.
The transaction is similar to a single-output checkpoint, with a few differences:
validation of Recovery is left to the user, as they are the ones broadcasting the
transaction and can refuse to do so until the vault signs the recovery; similarly,
the hashlock is not validated.

*Called by:** the user

#### Arguments:
* btcLockingTx: the full serialisation of the BTC transaction.
* witnessScript: the script which matches the P2WSH output's hash in btcLockingTx
* outputIndex: the exact output locking the backing coins for Issue
* blockHeight: the transaction's block height
* txIndex: the index of the transaction within its block (0-indexed)
* blockHeader: the header of the transaction's block
* merkleProof: the merkle proof of the transaction's inclusion it its block (intermediate hashes in the tree)


### `validateRedeem(uint256 redeemId, bytes btcLockingTx, uint64 outputIndex, uint32 blockHeight, uint256 txIndex, bytes blockHeader, bytes merkleProof)` (public)
Given a BTC transaction and the ID of a token burn, validates that the transaction
corresponds to the user redeeming the backing funds of the burn request.
Releases corresponding vault collateral if valid, if any.

*Called by:** anyone, though usually the vault


### `validateHashlockPreimage(address user, bytes32 preimage) → bool` (public)
Validates whether a given preimage corresponds to a user's next hashlock.

#### Arguments:
* user: the user to check
* preimage: the claimed preimage for the haslock


### `verifyCheckpoint(bytes checkpointTransaction, bytes[] witnessScripts, bytes[] recoverySignatures, address[] usersIncluded, uint32 blockHeight, uint256 txIndex, bytes blockHeader, bytes merkleProof)` (public)
Validates a checkpoint transaction. Releases collateral for involved users.
Reimburses from collateral for any users for whom the vault misbehaved.

#### Arguments:
* checkpointTransaction: the serialisation of the entire checkpoint tx
* witnessScripts: the witness scripts matching the P2WSH outputs in the checkpoint, in an order exactly corresponding to the transaction outputs order
* recoverySignatures: the signature data matching the recovery transactions for every output in the checkpoint, again in a matching order
* blockHeight: etc. are all inclusion proof items (see Issue).


### `balanceOf(address account) → uint256` (public)
****** Viewers *******


### `getNextHash(address user) → bytes32` (public)



### `getHashAt(address user, uint256 checkpointIndex) → bytes32` (public)



### `getRevealedPreimageOf(address user) → bytes32` (public)



### `getCheckpointIndex(address user) → uint256` (public)



### `getCollateralisationOf(address user) → uint256` (public)



### `getFrequencyOf(address user) → uint16` (public)



### `checkCollateralPoolOf(address vault) → uint256` (public)




### `UserRegistration(address addr, address vault, bytes32 btcKey)`
Notifies of a new user registering at a given vault.

### `VaultRegistration(address addr, bytes32 btcKey)`
Notifies of a new vault being registered.

### `UserHashlock(address addr, uint256 checkpointIndex, bytes32 hash)`
Fired on every change of any of a user's saved hashlocks digests (including setting new ones).

### `UserFrequencyChange(address user, uint16 newFreq)`
Fired when a user updates their checkpoint frequency preference

### `UserCollateralised(address addr, uint256 amount)`
Fired on user funds having collateral set.

### `Issue(address addr, uint256 amount)`
Fired when a user successfully executes Issue.

### `Redeem(address addr, uint256 amount, uint256 round)`
Fired when a user burns some of their tokens in order to redeem the backing funds.

### `HashlockReveal(address user, uint256 round, bytes32 preimage)`
Fires when the hashlock for the next round has its preimage revealed

### `Transfer(address from, address to, uint256 amount)`
Fired when a user transfers tokens to another user

