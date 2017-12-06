
# Fynance Crowdsale Security Audit *(Revision 2)*
Audit performed by Steven Ireland


## Overall Summary
Fynance is launching a crowdsale to raise ether, and in the process create a token for contributors. I (Steven Ireland) have been contracted to perform an audit on the accompanying solidity code. This is the second iteration of an audit, with the previous being available in their repository or upon request.

Performed on commit #7ff4a0f.

**No Major or minor vunerabilities are reported.**

This report documents the behaviour of the smart contracts involved in the crowdsale.


## "Proof Of Stake" Contract (PosContract.sol)
### Summary
The purpose of this contract is to reimburse previous donors. Investors can use their tokens to claim rewards that the owners have vested into the contract. Before any rewards are able to be collected, most functions call into `calculateDividend`. This method changes the contract state, calculating *and storing* a token holder's dividend rewards up to the latest deposit. It's key to note that this function is also called before any token transfers on both the sender and the recipient, thus ensuring that dividends are calculated only for previously-held tokens. The owners have a way to reclaim the value on deposits older than 12 weeks and removes those deposits from dividend calculation.
### Notable Warnings

```
Gas requirement of function browser/PosContract.sol:PosContract.calculateDividend(address)unknown or not constant.
If the gas requirement of a function is higher than the block gas limit, it cannot be executed. Please avoid loops in your functions or actions that modify large areas of storage (this includes clearing or copying arrays in storage)
```
The calculateDividend method loops over all deposits since the last dividend calculation. Each time there is a transfer to a new address, the contract will calculate dividends for every deposit since the latest owner withdrawal. Intended behaviour.

### Concerns ~~(1 MINOR)~~
- ~~MINOR: If the total supply of the tokens changes after a deposit is made, then the contract may not remain solvent. As an example: there are 100 tokens total and I own 50. I withdraw 50% of the funds from the PoS contract. 100 more are minted to another address, and they withdraw the remaining 50% of the tokens. The other person who had 50 tokens can no longer withdraw.~~ Deposit withdrawals are calculated based on the current supply at the time of deposit, and minting recalculates balances. The previous concern is now invalid.

### Commentary
- CalculateDividend requires approximately 53826 gas for a single deposit, and 116893 for ten. With the gas limit currently set to about 6 million gas, one can calculate that it would take > 9000 deposits to run out of gas. With monthly deposits there should be no out of gas errors possible.

## Token Contract (FynanceToken.sol)
### Summary
The token contract does not extend a pre-existing ERC20 token, and needfully has a few deviations from the norm. The constructor takes two addresses for different crowdsales, both having the same permissions. Because the token contract has distinct differences from a standard ERC20 token, summaries of the changed/added methods are below.
The following are standard functions, copied from StandardToken.sol (audited by Zeppelin Solidity):
##### Standard
- approve(spender, amount)
- balanceOf(address)

The following have modifications or exhibit non-standard token functionality and have further criticism below:

##### Non-Standard
- transfer(to, amount)
- transferFrom(from, to, amount)
- claimDividend()
- mint(to, amount)
- changePos(address)

##### transfer(to, amount) & transferFrom(from, to, amount)
Both of these functions share the same two first lines:
```solidity
  assert(pos.calculateDividend(_from));
  assert(pos.calculateDividend(_to));
```       

Before any tokens have moved, this will calculate dividends for both the sender and the receiver. This thwarts the strategy of moving tokens around and collecting dividends from multiple addresses, as each new receiver will have 0 dividends available. Accordingly, this necessarily increases the gas cost for any token transfers made. Approvals do not require this check.

##### claimDividend()
Another interface to PosContract.withdrawDividend

##### mint(to, amount)
Both crowdsales use this to create more tokens. The token contract has no logic controlling the amount of tokens available, therefore all of the accompanying logic is within the FynanceCrowdsale contract.

##### changePos(address)
A new PosContract may be assigned at any time.

### Notable Warnings
No notable warnings for FynanceToken are present besides those that stem from PosContract.

### Concerns ~~(1 MAJOR, 1 MINOR)~~
- ~~MAJOR: If the active PosContract is changed in the FynanceToken contract, and there are still deposits remaining in the old PosContract, it is possible for any malicious actor to drain its funds. Token transfers would no longer calculate dividends on the old PosContract before transfers, allowing anyone to send tokens to different addresses and withdraw ether until the contract is empty.~~ PosContracts will not be changed until they are empty. Deposits will be calculated by the owners and withdrawn manually before changing contracts.
- ~~Minor: Token transfers will not be possible until a PosContract is set. Any transfers attempted before then will cause a revert when calculating dividends.~~ A PosContract will be set before crowdsales are open.

### Commentary
Owners need to play an active role in ensuring smooth transition of PosContracts.

## Crowdsale Contract (FynanceCrowdsale.sol)
### Summary
This contract is responsible for accepting ether and minting tokens. The mint amount is a function of a discount rate, which changes as more tokens are created. Contributions of over 30 eth also get the highest discount rate. Ether raised is immediately transferred to an owner address, eliminating ether-draining attack surfaces. The owners are additionally able to withdraw tokens up to 15% of the total raised supply.
The contract has both a presale and a main sale, with the only differences being a different token rate, time range, and cap. The crowdsale can continue to mint tokens up until the end time or the main cap being reached.

### Notable Warnings
No warnings were found in this contract.

### Concerns
No concerns with this contract.

### Commentary
No comments for this contract.

## Scope
The primary goal of this audit is to ensure the token sale mechanisms in these contracts function smoothly and limit possible attack surfaces.

## Limitations

This audit makes no statements about the viability of Fynance's business proposition, the individuals involved in this business, or the regulatory bodies associated with the business.


This document was prepared by Steven Ireland for Fynance on 2017-12-05.

