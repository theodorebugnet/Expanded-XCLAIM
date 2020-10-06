//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.5.10 < 0.7.0;
pragma experimental ABIEncoderV2;

import "@nomiclabs/buidler/console.sol";

import {Relay} from '@interlay/btc-relay-sol/contracts/Relay.sol';
import {BTCUtils} from '@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol';
import {BytesLib} from '@interlay/bitcoin-spv-sol/contracts/BytesLib.sol';
import {Parser} from '@interlay/btc-relay-sol/contracts/Parser.sol';

import {ExchangeOracle} from './ExchangeOracle.sol';
import {Validator} from './Validator.sol';

contract XclaimCommit {
    using BTCUtils for bytes;
    using BytesLib for bytes;

    /* Events */

    /// Notifies of a new user registering at a given vault.
    event UserRegistration(
        address indexed addr,
        address indexed vault,
        bytes32 btcKey
    );

    /// Notifies of a new vault being registered.
    event VaultRegistration(
        address indexed addr,
        bytes32 btcKey
    );

    /// Fired on every change of any of a user's saved hashlocks digests (including setting new ones).
    event UserHashlock(
        address indexed addr,
        uint indexed checkpointIndex,
        bytes32 hash
    );

    /// Fired when a user updates their checkpoint frequency preference
    event UserFrequencyChange(
        address indexed user,
        uint16 newFreq
    );

    /// Fired on user funds having collateral set.
    event UserCollateralised(
        address indexed addr,
        uint amount
    );

    /// Fired when a user successfully executes Issue.
    event Issue(
        address indexed addr,
        uint amount
    );

    /// Fired when a user burns some of their tokens in order to redeem the backing funds.
    event Redeem(
        address indexed addr,
        uint amount,
        uint round
    );

    /// Fires when the hashlock for the next round has its preimage revealed
    event HashlockReveal(
        address indexed user,
        uint indexed round,
        bytes32 preimage
    );

    /// Fired when a user transfers tokens to another user
    event Transfer(
        address indexed from,
        address indexed to,
        uint amount
    );

    address public owner;

    ExchangeOracle exchangeOracle;
    Validator validator;
    Relay relay;

    uint public roundLength; // seconds between rounds
    uint public securityPeriod; // during which users due for a checkpoint must be collateralised
    uint public timelockLeniency; // for fluctuations in block length etc.
    uint public round;
    uint public roundDueAt;
//    uint public redeemTimeout; // in rounds

    uint public totalSupply;

    struct User {
        bytes32 btcKey;
        uint balance;
        uint collateralisation;
        uint16 frequency;
        bytes32 prevCheckpointTxid;
        bytes recoverySig;
        bytes32 preimage;
        address vault;
        mapping(uint => bytes32) hashlist;
        uint64 checkpointIndex; //last checkpoint transaction - used to keep track of current hashlock
        uint nextRoundDue;
    }

    struct Vault {
        bytes32 btcKey;
        uint freeCollateral;
    }

    mapping (address => User) public users;
    mapping (address => Vault) public vaults;

    // prevent replay attacks
    mapping (bytes32 => bool) public usedTransactions;

    // validating Redeem vault misbehaviour
    struct RedeemRequest {
        address user;
        uint amount;
    }
    uint redeemUid;
    mapping (uint => RedeemRequest) redeemRequests;

    /// Initialises values, and sets addresses for auxilliary contracts
    constructor(address relayAddr, address exchangeOracleAddr, address validatorAddr) public {
        owner = msg.sender;
        roundLength = 12 * 60 * 60; // half a day
        round = 0;
        roundDueAt = block.timestamp + roundLength; // schedule next round
        timelockLeniency = 600; // 10 minutes += on the scheduled round

        exchangeOracle = ExchangeOracle(exchangeOracleAddr);
        relay = Relay(relayAddr);
        validator = Validator(validatorAddr);
    }

    /// When a vault performs an operation on a user, revert unless the user is registered with that vault.
    modifier vaultHasUser(address vault, address user) {
        require(users[user].vault == vault, "User does not correspond to this vault");
        _;
    }

    /// Revert if an address does not match any registered vault.
    modifier vaultExists(address vault) {
        require(vaults[vault].btcKey != 0x0, "No such vault exists");
        _;
    }

    /// Checks whether the user is able to carry out normal operations, e.g. trading,
    /// which are suspended when a round is over until the round's checkpoint is verified.
    /// Users are of course only affected by rounds where they are scheduled for a checkpoint.
    modifier userNotDueForCheckpoint(address user) {
        if (users[msg.sender].nextRoundDue <= round) { // due at the end of this round, or overdue
            if (block.timestamp >= roundDueAt) { // ...and the round is over
                revert("User is due for a checkpoint, unable to proceed");
            }
        }
        _;
    }

    /// Increments round if previous round length has been exceeded.
    /// Due to ETH block times, rounds will vary +=10s to a minute, so rounds should
    /// be long enough for this to not matter. Frequent rounds give more flexibility
    /// for scheduling users, but are otherwise not necessary. ~1h per round is reasonable.
    modifier roundScheduler() {
        if (block.timestamp >= roundDueAt) {
            ++round;
            roundDueAt += roundLength;
        }
        _;
    }

    /******** Registration ********/

    /// Creates a new user, registered to a given vault (which must exist), and optionally sets
    /// hashes to use for future hashlocks
    /// ***Called by:** the user registering
    function registerUser(bytes32 btcKey, address vaultaddr, uint16 frequency, bytes32[] memory hashes)
    public
    roundScheduler
    vaultExists(vaultaddr)
    {
        require (users[msg.sender].btcKey == 0x0, "User already exists.");

        emit UserRegistration(msg.sender, vaultaddr, btcKey);

        // init core values, leaving the rest default
        User memory newUser;
        newUser.btcKey = btcKey;
        newUser.vault = vaultaddr;
        newUser.frequency = frequency;
        newUser.checkpointIndex = 0;
        users[msg.sender] = newUser;

        // save the hashes for subsequent checkpoints
        for (uint i = 0; i < hashes.length; ++i) {
            users[msg.sender].hashlist[i] = hashes[i];
            emit UserHashlock(msg.sender, i, hashes[i]);
        }
    }

    /// Updates the future hashes saved for the user, which can both add to the existing list
    /// or overwrite already set ones (e.g. if the user loses their preimages)
    ///  **Called by:** the user updating their hashes
    /// @param hashes a list of hashes to save
    /// @param checkpoints a list of checkpoint indices, corresponding 1:1 to the element hash at the same array location. They denote a user's checkpoint counter (with user.checkpointIndex being the next one that will be used).
    function updateHashlist(bytes32[] memory hashes, uint[] memory checkpoints)
    public
    roundScheduler
    {
        require(hashes.length == checkpoints.length, "Number of indices must match number of hashes");
        for (uint i = 0; i < hashes.length; i++) {
            require(checkpoints[i] >= users[msg.sender].checkpointIndex,
                    "Cannot update hash for past checkpoints.");
            users[msg.sender].hashlist[checkpoints[i]] = hashes[i];
            emit UserHashlock(msg.sender, checkpoints[i], hashes[i]);
        }
    }

    /// Allows the user to change their checkpoint frequency. Does not validate with
    /// the vault - negotiations will happen off-chain (the vault can always refuse service
    /// in the event of a dispute).
    ///  ***Called by:** the user
    function updateFrequency(uint16 newFreq)
    public
    roundScheduler
    {
        emit UserFrequencyChange(msg.sender, newFreq);
        users[msg.sender].frequency = newFreq;
    }

    /// Registers a vault with the given BTC address. No commitment is required; to
    /// provide a useful list of vaults, interfaces may wish to sort by e.g. amount
    /// of collateral available in the vault's pool.
    /// **Called by:** the vault
    function registerVault(bytes32 btcKey)
    public
    roundScheduler
    {
        emit VaultRegistration(msg.sender, btcKey);
        vaults[msg.sender] = Vault({
            btcKey: btcKey,
            freeCollateral: 0
        });
    }

    /******** Vault collateral ********/

    /// Allows the vault to deposit funds that can be used to collateralise
    /// (but which are not yet locked)
    /// **Called by:** the vault
    function topUpCollateralPool()
    payable public
    roundScheduler
    {
        vaults[msg.sender].freeCollateral += msg.value;
    }

    /// Allows the vault to withdraw unlocked collateral funds
    /// **Called by:** the vault
    function drainCollateralPool(uint amount)
    public
    roundScheduler
    {
        require(amount < vaults[msg.sender].freeCollateral, "Insufficient free collateral to fulfill drain request");
        vaults[msg.sender].freeCollateral -= amount;
        msg.sender.transfer(amount);
    }

    /******** User-locked collateral ********/

    /// Locks a specified amount of collateral against a user. Collateral is specified
    /// in ETH (while the tokens are in BTC), hence the exchange rate oracle is used
    /// (the oracle is also responsible for any overcollateralisation which may be
    /// necessary over the short time a user is expected to be collateralised).
    /// **Called by:** the vault
    function lockCollateral(address user, uint amount)
    payable public
    roundScheduler
    vaultHasUser(msg.sender, user)
    {
        vaults[msg.sender].freeCollateral += msg.value;
        uint uncollateralised = exchangeOracle.btcToEth(users[user].balance) - users[user].collateralisation;
        if (amount > uncollateralised) {
            amount = uncollateralised;
        }
        require(vaults[msg.sender].freeCollateral >= amount, "Insufficient free collateral to fulfill lock request");
        users[user].collateralisation += amount;
        vaults[msg.sender].freeCollateral -= amount;
        emit UserCollateralised(user, amount);
    }

    /// Helper function used to unlock vault collateral locked against a user.
    function releaseCollateral(address vault, address user, uint amount)
    internal
    roundScheduler
    vaultHasUser(vault, user)
    {
        if (amount > users[user].collateralisation) {
            amount = users[user].collateralisation;
        }
        users[user].collateralisation -= amount;
        vaults[vault].freeCollateral += amount;
    }

    /******** Token lifecycle ********/

    /// Destroys the amount of tokens requested by the users.
    /// User must then proceed with the appropriate steps to redeem or recover
    /// their backing funds.
    /// **Called by:** the user
    /// @return the ID of this redeem request (to be used later to release vault collateral or reimburse the user)
    function burnTokens(uint btcAmount)
    public
    roundScheduler
    returns (uint)
    {
        require(btcAmount <= users[msg.sender].balance, "Burn request exceeds account balance");
        users[msg.sender].balance -= btcAmount;
        totalSupply -= btcAmount;
        redeemRequests[++redeemUid] = RedeemRequest({ user: msg.sender, amount: btcAmount });
        emit Redeem(msg.sender, btcAmount, round);
        return redeemUid;
    }

    /// Helper function which slashes vault collateral and provides it to the user,
    /// burning a corresponding amount of user tokens.
    function reimburse(address user, uint btcAmount)
    internal
    roundScheduler
    {
        uint ethAmount = exchangeOracle.btcToEth(btcAmount);
        require(ethAmount <= users[user].collateralisation, "Insufficient collateral to reimburse");
        users[user].balance -= btcAmount;
        users[user].collateralisation -= ethAmount;
        (bool success, ) = user.call{value: ethAmount}("");
        require(success, "Transfer to user failed.");
    }

    function transfer(address recipient, uint amount)
    public
    roundScheduler
    userNotDueForCheckpoint(msg.sender)
    {
        require(users[msg.sender].preimage != 0x0, "Must reveal hashlock preimage before initiating Transfer.");
        require(users[msg.sender].balance >= amount, "Insufficient balance to cover transfer.");
        require(users[recipient].btcKey != 0x0, "Recipient is not registered."); //TODO - auto-register recipient with default values
        users[msg.sender].balance -= amount;
        users[recipient].balance += amount;
        emit Transfer(msg.sender, recipient, amount);
    }

    /// Given a valid Issue transaction on BTC, credits the user with the corresponding amount
    /// of backed tokens.
    /// The transaction is similar to a single-output checkpoint, with a few differences:
    /// validation of Recovery is left to the user, as they are the ones broadcasting the
    /// transaction and can refuse to do so until the vault signs the recovery; similarly,
    /// the hashlock is not validated.
    /// **Called by:** the user
    /// @param btcLockingTx the full serialisation of the BTC transaction.
    /// @param witnessScript the script which matches the P2WSH output's hash in btcLockingTx
    /// @param outputIndex the exact output locking the backing coins for Issue
    /// @param blockHeight the transaction's block height
    /// @param txIndex the index of the transaction within its block (0-indexed)
    /// @param blockHeader the header of the transaction's block
    /// @param merkleProof the merkle proof of the transaction's inclusion it its block (intermediate hashes in the tree)
    function issueTokens(
        bytes memory btcLockingTx,
        bytes memory witnessScript,
        uint64 outputIndex,
        uint32 blockHeight,
        uint256 txIndex,
        bytes memory blockHeader,
        bytes memory merkleProof
    )
    public
    roundScheduler
    {
        require(users[msg.sender].btcKey != 0x0, "User does not exist.");

        // get txId, check the transaction has been verified
        // to exist on BTC, and check it's not a replay
        bytes32 txId = btcLockingTx.hash256();
        require(usedTransactions[txId] == false, "Issue request has already been processed for this transaction.");
        require(relay.verifyTx(blockHeight, txIndex, txId, blockHeader, merkleProof, 6, false), "Transaction could not be verified to have been included in the blockchain.");

        // ensure the script is valid for this user, and extract the amount to be issued
        uint outputVal = validator.checkIssueTx(
            btcLockingTx,
            witnessScript,
            outputIndex,
            users[msg.sender].btcKey,
            vaults[users[msg.sender].vault].btcKey,
            roundDueAt + users[msg.sender].frequency * roundLength // when should the next checkpoint be?
        );
        users[msg.sender].balance += outputVal;
        users[msg.sender].nextRoundDue = round + users[msg.sender].frequency; // schedule the next checkpoint
        users[msg.sender].prevCheckpointTxid = txId;
        totalSupply += outputVal;

        //add to replay protection records
        usedTransactions[txId] = true;

        //emit event
        emit Issue(msg.sender, outputVal);
    }

    /// Given a BTC transaction and the ID of a token burn, validates that the transaction
    /// corresponds to the user redeeming the backing funds of the burn request.
    /// Releases corresponding vault collateral if valid, if any.
    /// **Called by:** anyone, though usually the vault
    function validateRedeem(
        uint redeemId,
        bytes memory btcLockingTx,
        uint64 outputIndex,
        uint32 blockHeight,
        uint256 txIndex,
        bytes memory blockHeader,
        bytes memory merkleProof
    )
    public
    roundScheduler
    {
        address user = redeemRequests[redeemId].user;

        // validate TX, check it exists and hasn't already been used
        bytes32 txId = btcLockingTx.hash256();
        require(usedTransactions[txId] == false, "Redeem request has already been processed for this transaction.");
        require(relay.verifyTx(blockHeight, txIndex, txId, blockHeader, merkleProof, 6, false), "Transaction could not be verified to have been included in the blockchain.");

        // validate output of btcLockingTx (p2wpk)
        uint outputVal = validator.checkRedeemTx(
            btcLockingTx,
            outputIndex,
            users[user].btcKey
        );
        require (outputVal >= redeemRequests[redeemId].amount, "Insufficient output value for redeem request"); //todo - support partial redeems?
        
        // add to replay protection
        usedTransactions[txId] = true;
        // release Vault's collateral
        releaseCollateral(users[user].vault, user, users[user].collateralisation);
    }

    /// Validates whether a given preimage corresponds to a user's next hashlock.
    /// @param user the user to check
    /// @param preimage the claimed preimage for the haslock
    function validateHashlockPreimage(address user, bytes32 preimage)
    public
    returns (bool)
    {
        // check if hash digest matches previous checkpoint's hashlock
        if (BTCUtils.hash256(abi.encodePacked(preimage)) != users[user].hashlist[users[user].checkpointIndex]) {
            revert("Invalid preimage!");
        } else {
            // save it for public use
            users[user].preimage = preimage;
            emit HashlockReveal(user, round, preimage);
            return true;
        }
    }

    /// Validates a checkpoint transaction. Releases collateral for involved users.
    /// Reimburses from collateral for any users for whom the vault misbehaved.
    /// @param checkpointTransaction the serialisation of the entire checkpoint tx
    /// @param witnessScripts the witness scripts matching the P2WSH outputs in the checkpoint, in an order exactly corresponding to the transaction outputs order
    /// @param recoverySignatures the signature data matching the recovery transactions for every output in the checkpoint, again in a matching order
    /// @param blockHeight etc. are all inclusion proof items (see Issue).
    function verifyCheckpoint(
        bytes memory checkpointTransaction,
        bytes[] memory witnessScripts,
        bytes[] memory recoverySignatures,
        address[] memory usersIncluded,
        uint32 blockHeight,
        uint256 txIndex,
        bytes memory blockHeader,
        bytes memory merkleProof
    )
    public
    roundScheduler
    {
        //This code is ugly because stack limit and contract size limit was met, and there is a lot of state to pass around which makes splitting it into functions non-trivial
        //TODO: refactor this as much as possible

        // first validate user list
        for (uint i = 0; i < usersIncluded.length; ++i)
        {
            require(users[usersIncluded[i]].nextRoundDue <= round, "An included user is not due yet.");
        }

        // verify txId + inclusion
        bytes32 txId = checkpointTransaction.hash256();
        require(usedTransactions[txId] == false, "Redeem request has already been processed for this transaction.");
        require(relay.verifyTx(blockHeight, txIndex, txId, blockHeader, merkleProof, 6, false), "Transaction could not be verified to have been included in the blockchain.");
        (bytes memory outputs, uint numOut) = validator.quickParseCheckpointTx(
            checkpointTransaction,
            witnessScripts.length,
            recoverySignatures.length,
            usersIncluded.length
        );

        // loop
        for (uint i = 0; i < numOut; i++) {
            address u = usersIncluded[i]; // for convenience

            // validate many things
            validator.validateUserCheckpointValues(
                outputs,
                i,
                witnessScripts[i],
                users[u].balance,
                users[u].btcKey,
                vaults[users[u].vault].btcKey,
                roundDueAt - block.timestamp + users[u].frequency * roundLength,
                timelockLeniency
            );

            // verify recovery transaction
            validator.validateRecoverySig(
                recoverySignatures[i],
                users[u].hashlist[users[u].checkpointIndex + 1],
                users[u].btcKey,
                vaults[users[u].vault].btcKey,
                users[u].prevCheckpointTxid
            );

            //valid!
            // update: cp index, preimage, recsig, previous cp txid; release collateral
            users[u].checkpointIndex = users[u].checkpointIndex + 1;
            users[u].preimage = 0x0;
            users[u].recoverySig = recoverySignatures[i];
            users[u].prevCheckpointTxid = txId;
            releaseCollateral(users[u].vault, u, users[u].collateralisation);

            // else reimburse
            // TODO - improve reimbursing mechanism - change all the reverts to bubbling up errors? or change protocol to allow users to claim reimbursement if they haven't been checkpointed within a certain time?
        }
    }

    /******** Viewers ********/

    function balanceOf(address account)
    public view
    returns (uint256)
    {
        return users[account].balance;
    }

    function getNextHash(address user)
    public view
    returns (bytes32)
    {
        return users[user].hashlist[users[user].checkpointIndex];
    }

    function getHashAt(address user, uint checkpointIndex)
    public view
    returns (bytes32)
    {
        return users[user].hashlist[checkpointIndex];
    }

    function getRevealedPreimageOf(address user)
    public view
    returns (bytes32)
    {
        return users[user].preimage;
    }

    function getCheckpointIndex(address user)
    public view
    returns (uint)
    {
        return users[user].checkpointIndex;
    }

    function getCollateralisationOf(address user)
    public view
    returns (uint)
    {
        return users[user].collateralisation;
    }

    function getFrequencyOf(address user)
    public view
    returns (uint16)
    {
        return users[user].frequency;
    }

    function checkCollateralPoolOf(address vault)
    public view
    vaultExists(vault)
    returns (uint)
    {
        return vaults[vault].freeCollateral;
    }
}
