# XCLAIM Commit
Proof of concept implementation of XCC.

## External requirements
This implementation depends on an exchange rate oracle, and a Bitcoin SPV client.

* A mock exchange rate oracle is provided.
* BTCRelay can be used for SPV verification. (Mock is provided for testing and development.)

## Structure and functionality
Paper link TBA.

### XclaimCommit.sol
Keeps track of users, vaults, their balances and accounting. Implements registration, issue, redeem, collateralisation, checkpoints and hashlock management.
### Validator.sol
Auxilliary contract used to assist in validation of Bitcoin transactions, including scripts, values, etc.

## Building and deployment
 * Build:
```
npx buidler compile
```
 * Test:
```
npm test
```
 * Regenerate docs:
```
npm run docs
```
 * Deploy on a local buidler EVM:
```
npm run localdeploy
```

## XCC Usage
Refer to docs for API details. A vault must be registered first, then a user can be registered with it. The user can then submit proof of a Bitcoin Issue transaction to get tokens created. These can then be collateralised by the vault (negotiation between user and vault happens off-chain), traded (once collateralised and the hashlock is revealed), redeemed, and included in a checkpoint (which releases collateral).

Recovery happens purely on Bitcoin. The contract does not implement deposit-based incentives as described in the paper, so stale tokens could potentially exist forever (though the only negative effect would be cluttering potential explorer/viewing frontends, as such stale tokens are not usable).
