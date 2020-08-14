//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.5.0 < 0.7.0;

import {Parser} from '@interlay/btc-relay-sol/contracts/Parser.sol';
import {Relay} from '@interlay/btc-relay-sol/contracts/Relay.sol';
import {ExchangeOracle} from './ExchangeOracle.sol';

contract Roundclaim {
    event UserRegistration(
        address indexed addr,
        address indexed vault,
        bytes20 btcaddr
    );

    event VaultRegistration(
        address indexed addr
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

    address public owner;

    ExchangeOracle exchangeOracle;

    uint public roundLength; // seconds between rounds
    uint public round;

    uint public totalSupply;

    constructor() public {
        owner = msg.sender;
        roundLength = 84600;
        round = 0;
        exchangeOracle = new ExchangeOracle();
    }

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
        uint freeCollateral;
        bool registered = true;
    }

    mapping (address => User) public users;
    mapping (address => Vault) public vaults;
//    mapping (uint => uint) usersByVault;
    
    modifier senderVaultHasUser(address user) {
        require(users[user].vault == msg.sender, "User does not correspond to this vault");
        _;
    }

    /******** Registration ********/

    function registerUser(bytes20 btcaddr, address vaultaddr, uint16 frequency, bytes32[] memory hashes) public {
        emit UserRegistration(msg.sender, vaultaddr, btcaddr);
        User memory newUser;
        newUser.btcAddress = btcaddr;
        newUser.vault = vaultaddr;
        newUser.frequency = frequency;
        users[msg.sender] = newUser;
        for (uint i = 0; i < hashes.length; i++) {
            users[msg.sender].hashlist[i + round] = hashes[i];
        }
    }

    function updateHashlist(bytes32[] memory hashes, uint[] memory rounds) public {
        require(hashes.length == rounds.length, "Number of indices must match number of hashes");
        for (uint i = 0; i < hashes.length; i++) {
            require(rounds[i] >= round, "Cannot update hash for past rounds.");
            users[msg.sender].hashlist[rounds[i]] = hashes[i];
        }
    }

    function updateFrequency(uint16 newFreq) public {
        users[msg.sender].frequency = newFreq;
    }

    function registerVault() public {
        vaults[msg.sender] = Vault({
            freeCollateral: 0,
            registered: true
        });
    }

    /******** Vault collateral ********/

    function topUpCollateralPool() payable public {
        vaults[msg.sender].freeCollateral += msg.value;
    }

    function drainCollateralPool(uint amount) public {
        require(amount < vaults[msg.sender].freeCollateral, "Insufficient free collateral to fulfill drain request");
        vaults[msg.sender].freeCollateral -= amount;
        msg.sender.transfer(amount);
    }

    /******** User-locked collateral ********/

    function lockCollateral(address user, uint amount) payable public
    senderVaultHasUser(user) {
        vaults[msg.sender].freeCollateral += msg.value;
        uint uncollateralised = exchangeOracle.btcToEth(users[user].balance) - users[user].collateralisation;
        if (amount > uncollateralised) {
            amount = uncollateralised;
        }
        require(vaults[msg.sender].freeCollateral >= amount, "Insufficient free collateral to fulfill lock request");
        users[user].collateralisation += amount;
        vaults[msg.sender].freeCollateral -= amount;
    }

    function releaseCollateral(address user, uint amount) public
    senderVaultHasUser(user) {
        if (amount > users[user].collateralisation) {
            amount = users[user].collateralisation;
        }
        users[user].collateralisation -= amount;
        vaults[msg.sender].freeCollateral += amount;
    }

    function burnTokens(uint btcAmount) public {
        require(exchangeOracle.btcToEth(btcAmount) <= users[msg.sender].balance, "Burn request exceeds account balance");
        users[msg.sender].balance -= btcAmount;
    }

    function reimburse(address user, uint btcAmount) internal {
        uint ethAmount = exchangeOracle.btcToEth(btcAmount);
        require(ethAmount <= users[user].collateralisation, "Insufficient collateral to reimburse");
        users[user].balance -= btcAmount;
        users[user].collateralisation -= ethAmount;
        (bool success, ) = user.call{value: ethAmount}("");
        require(success, "Transfer to user failed.");
    }

    function checkCheckpointOutput(address user) public view
    returns (uint amount) {
    }

    function issueTokens(
        bytes memory btcLockingTx,
        uint32 height,
        uint256 index,
        bytes memory header,
        bytes memory proof
    ) public {
        bytes32 txId; //TODO: calc
        //TODO: validate btcLockingTx output script:
        //  - get output script
        //  - get value
        //  - get sig
        bool validTx = Relay.verifyTx(height, index, txId, header, proof, 6, false);
        require(validTx, "An invalid transaction was used");
        //validate transaction, get output value
        //add balance to user
        //add balance to totalSupply
    }

    /******** Viewers ********/

    function getBalance() public view returns (uint) {
        return users[msg.sender].balance;
    }

    function balanceOf(address account) public view returns (uint256) {
        return users[account].balance;
    }

    function getHashes(uint limit) public view returns (bytes32[] memory out) {
        out = new bytes32[](limit);
        for (uint i = 0; i < limit; i++) {
            out[i] = users[msg.sender].hashlist[i + round];
        }
    }
}
