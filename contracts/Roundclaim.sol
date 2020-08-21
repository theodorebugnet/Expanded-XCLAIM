//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.5.10 < 0.7.0;

import {Parser} from '@interlay/btc-relay-sol/contracts/Parser.sol';
import {Relay} from '@interlay/btc-relay-sol/contracts/Relay.sol';
import {BTCUtils} from '@interlay/bitcoin-spv-sol/contracts/BTCUtils.sol';
import {BytesLib} from '@interlay/bitcoin-spv-sol/contracts/BytesLib.sol';
import {ExchangeOracle} from './ExchangeOracle.sol';

contract Roundclaim {
    using BTCUtils for bytes;
    using BytesLib for bytes;

    event UserRegistration(
        address indexed addr,
        address indexed vault,
        bytes20 btcaddr
    );

    event VaultRegistration(
        address indexed addr,
        bytes20 btcaddr
    );

    event UserHashlock(
        address indexed addr,
        uint indexed round,
        bytes32 hash
    );

    event UserCollateralised(
        address indexed addr,
        uint amount
    );

    event Issue(
        address indexed addr,
        uint amount
    );

    address public owner;

    ExchangeOracle exchangeOracle;
    Relay relay;

    uint public roundLength; // seconds between rounds
    uint public round;

    uint public totalSupply;

    struct User {
        bytes20 btcAddress;
        uint balance;
        uint collateralisation;
        uint16 frequency;
        bytes32 recSig1;
        bytes32 recSig2;
        bytes9  recSig3;
        bytes16 preimage;
        address vault;
        mapping(uint => bytes32) hashlist;
    }

    struct Vault {
        bytes20 btcAddress;
        uint freeCollateral;
    }

    mapping (address => User) public users;
    mapping (address => Vault) public vaults;
//    mapping (uint => uint) usersByVault;

    mapping (bytes32 => bool) public usedTransactions;

    modifier senderVaultHasUser(address user) {
        require(users[user].vault == msg.sender, "User does not correspond to this vault");
        _;
    }

    modifier vaultExists(address vault) {
        require(vaults[vault].btcAddress != 0x0, "No such vault exists");
        _;
    }

    constructor(address relayAddr, address exchangeOracleAddr) public {
        owner = msg.sender;
        roundLength = 84600;
        round = 0;
        exchangeOracle = ExchangeOracle(exchangeOracleAddr);
        relay = Relay(relayAddr);
    }

    /******** Registration ********/

    function registerUser(bytes20 btcaddr, address vaultaddr, uint16 frequency, bytes32[] memory hashes)
    public
    vaultExists(vaultaddr)
    {
        emit UserRegistration(msg.sender, vaultaddr, btcaddr);
        User memory newUser;
        newUser.btcAddress = btcaddr;
        newUser.vault = vaultaddr;
        newUser.frequency = frequency;
        users[msg.sender] = newUser;
        for (uint i = 0; i < hashes.length; i += frequency) {
            users[msg.sender].hashlist[i + round] = hashes[i];
            emit UserHashlock(msg.sender, i + round, hashes[i]);
        }
    }

    function updateHashlist(bytes32[] memory hashes, uint[] memory rounds)
    public
    {
        require(hashes.length == rounds.length, "Number of indices must match number of hashes");
        for (uint i = 0; i < hashes.length; i++) {
            require(rounds[i] >= round, "Cannot update hash for past rounds.");
            users[msg.sender].hashlist[rounds[i]] = hashes[i];
            emit UserHashlock(msg.sender, rounds[i], hashes[i]);
        }
    }

    function updateFrequency(uint16 newFreq)
    public
    {
        users[msg.sender].frequency = newFreq;
    }

    function registerVault(bytes20 btcaddr)
    public
    {
        emit VaultRegistration(msg.sender, btcaddr);
        vaults[msg.sender] = Vault({
            btcAddress: btcaddr,
            freeCollateral: 0
        });
    }

    /******** Vault collateral ********/

    function topUpCollateralPool()
    payable public
    {
        vaults[msg.sender].freeCollateral += msg.value;
    }

    function drainCollateralPool(uint amount)
    public
    {
        require(amount < vaults[msg.sender].freeCollateral, "Insufficient free collateral to fulfill drain request");
        vaults[msg.sender].freeCollateral -= amount;
        msg.sender.transfer(amount);
    }

    /******** User-locked collateral ********/

    function lockCollateral(address user, uint amount)
    payable public
    senderVaultHasUser(user)
    {
        vaults[msg.sender].freeCollateral += msg.value;
        uint uncollateralised = exchangeOracle.btcToEth(users[user].balance) - users[user].collateralisation;
        if (amount > uncollateralised) {
            amount = uncollateralised;
        }
        require(vaults[msg.sender].freeCollateral >= amount, "Insufficient free collateral to fulfill lock request");
        users[user].collateralisation += amount;
        vaults[msg.sender].freeCollateral -= amount;
    }

    function releaseCollateral(address user, uint amount)
    public
    senderVaultHasUser(user)
    {
        if (amount > users[user].collateralisation) {
            amount = users[user].collateralisation;
        }
        users[user].collateralisation -= amount;
        vaults[msg.sender].freeCollateral += amount;
    }

    function burnTokens(uint btcAmount)
    public
    {
        require(exchangeOracle.btcToEth(btcAmount) <= users[msg.sender].balance, "Burn request exceeds account balance");
        users[msg.sender].balance -= btcAmount;
    }

    function reimburse(address user, uint btcAmount)
    internal
    {
        uint ethAmount = exchangeOracle.btcToEth(btcAmount);
        require(ethAmount <= users[user].collateralisation, "Insufficient collateral to reimburse");
        users[user].balance -= btcAmount;
        users[user].collateralisation -= ethAmount;
        (bool success, ) = user.call{value: ethAmount}("");
        require(success, "Transfer to user failed.");
    }

    function checkpointOutputValid(bytes memory outputScript, bytes memory witnessScript, address user)
    internal view
    returns (bool valid)
    {
        // does the script hash from the output match the witness script?
        // is the script of the right format? Get sigs and locktime
        // does the locktime match user?
        // does the vault sig match the user's vault's btc address?
        // does the multisig match the user's and the vault's addresses?
        valid = true;
    }

    function issueTokens(
        bytes memory btcLockingTx,
        bytes memory witnessScript,
        uint64 outputIndex,
        uint32 height,
        uint256 index,
        bytes memory header,
        bytes memory proof
    )
    public
    {
        // get txId and prevent replay attacks
        bytes32 txId = btcLockingTx.hash256();
        require(usedTransactions[txId] == false, "Issue request has already been processed for this transaction.");

        //get the output
        (, uint lenIn) = Parser.extractInputLength(btcLockingTx); //find start of outputs data
        bytes memory outputs = btcLockingTx.slice(lenIn, btcLockingTx.length - lenIn);
        bytes memory output = Parser.extractOutputAtIndex(outputs, outputIndex);

        //is script valid?
        bytes memory script = Parser.extractOutputScript(output);
        require(checkpointOutputValid(script, witnessScript, msg.sender),
                "Submitted transaction contained no valid outputs for locking funds.");
        //is tx valid?
        require(relay.verifyTx(height, index, txId, header, proof, 6, false), "Transaction could not be verified to have been included in the blockchain.");

        //add balance to user and supply
        uint outputVal = Parser.extractOutputValue(output);
        users[msg.sender].balance += outputVal;
        totalSupply += outputVal;

        //add to replay protection records
        usedTransactions[txId] = true;

        //emit event
        emit Issue(msg.sender, outputVal);
    }

    /******** Viewers ********/

    function getBalance()
    public view
    returns (uint)
    {
        return users[msg.sender].balance;
    }

    function balanceOf(address account)
    public view
    returns (uint256)
    {
        return users[account].balance;
    }

    function getHashes(uint limit)
    public view
    returns (bytes32[] memory out)
    {
        out = new bytes32[](limit);
        for (uint i = 0; i < limit; i++) {
            out[i] = users[msg.sender].hashlist[i + round];
        }
    }
}
