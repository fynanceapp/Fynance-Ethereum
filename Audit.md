
# Fynance Crowdsale Security Audit
Audit performed by Steven Ireland


## Overall Summary
Fynance is launching a crowdsale to raise ether, and in the process create a token for contributors. I (Steven Ireland) have been contracted to perform an audit on the accompanying solidity code.

This audit has been performed on commit b654be1d6693dfa0abe9e2dc809701be73f0006c.

1 Major vulnerability and 2 Minor vulnerabilities have been discovered.

This report documents the behaviour of the smart contracts involved in the crowdsale.


## "Proof Of Stake" Contract (PosContract.sol)
### Summary
The purpose of this contract is to reimburse previous donors. Investors can use their tokens to claim rewards that the owners have vested into the contract. Before any rewards are able to be collected, most functions call into `calculateDividend`. This method changes the contract state, calculating *and storing* a token holder's dividend rewards up to the latest deposit. It's key to note that this function is also called before any token transfers on both the sender and the recipient, thus ensuring that dividends are calculated only for previously-held tokens. The owners have a way to reclaim the value on deposits older than 12 weeks and removes those deposits from dividend calculation.
### Notable Warnings
```
browser/PosContract.sol:102:16: Warning: Function declared as view, but this expression (potentially) modifies the state and thus requires non-payable (the default) or payable.
        assert(calculateDividend(_user));
               ^----------------------^
```
The method checkDividend that this assertion is within is not constant, because calculateDividend does modify contract state. This assertion is probably not meant in this way and should be removed.

```
Gas requirement of function browser/PosContract.sol:PosContract.calculateDividend(address)unknown or not constant.
If the gas requirement of a function is higher than the block gas limit, it cannot be executed. Please avoid loops in your functions or actions that modify large areas of storage (this includes clearing or copying arrays in storage)
```
The calculateDividend method loops over all deposits since the last dividend calculation. Each time there is a transfer to a new address, the contract will calculate dividends for every deposit since the latest owner withdrawal.

### Concerns (1 MINOR)
- MINOR: If the total supply of the tokens changes after a deposit is made, then the contract may not remain solvent. As an example: there are 100 tokens total and I own 50. I withdraw 50% of the funds from the PoS contract. 100 more are minted to another address, and they withdraw the remaining 50% of the tokens. The other person who had 50 tokens can no longer withdraw.

### Recommendations
- Remove the assertion from the checkDividend public method to eliminate state changes. If an up-to-date calculation is needed, the calculation can be separated into a different constant method that both checkDividend and calculateDividend call.
- Regarding the gas limit of calculateDividend, in testing, this function requires approximately 53826 gas for a single deposit, and 116893 for ten. With the gas limit currently set to about 6 million gas, one can calculate that it would take > 9000 deposits to run out of gas. While unlikely, it's my recommendation that deposits are kept infrequent and in larger denominations to reduce the amount of gas regular token users would have to pay.
    - A simple enhancement could be to explicitly check for zero-token-balances and avoid looping over deposits for those dividend calculations, as their dividend will always sum to 0.
- While the PosContract can be used while the crowdsales are ongoing, I recommend either:
    1. Adding a "crowdsales are done" assertion to claimDividend and restricting the PosContract's withdrawDividend method to the FynanceToken only.
    2. Not depositing to the PosContract while either crowdsale is live.


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

#### changePos(address)
A new PosContract may be assigned at any time.

### Notable Warnings
No notable warnings for FynanceToken are present besides those that stem from PosContract.

### Concerns (1 MAJOR, 1 MINOR)
- MAJOR: If the active PosContract is changed in the FynanceToken contract, and there are still deposits remaining in the old PosContract, it is possible for any malicious actor to drain its funds. Token transfers would no longer calculate dividends on the old PosContract before transfers, allowing anyone to send tokens to different addresses and withdraw ether until the contract is empty.
- Minor: Token transfers will not be possible until a PosContract is set. Any transfers attempted before then will cause a revert when calculating dividends.

### Recommendations
- Both addresses that are used in the constructor should be audited smart contracts. If an address under owner control is used as a substitute, it exposes the PosContract solvency problem because tokens could forever be minted at any time.
- In order to prevent the problem with changing PosContracts, I recommend taking one of two actions:
    1. Only call FynanceToken.changePos after PosContract.ownerWithdraw has withdrawn all remaining funds in the old PosContract
    2. Calculate and withdraw dividends for all parties before changing PosContracts. Keep in mind that if a smart contract is an owner of tokens this has the possibility of failing to withdraw for those accounts.

## Crowdsale Contract (FynanceCrowdsale.sol)
### Summary
This contract is responsible for accepting ether and minting tokens. The mint amount is a function of a discount rate, which changes as more tokens are created. Contributions of over 30 eth also get the highest discount rate. Ether raised is immediately transferred to an owner address, eliminating ether-draining attack surfaces. The owners are additionally able to withdraw tokens up to 15% of the total raised supply.
The contract has both a presale and a main sale, with the only differences being a different token rate, time range, and cap. The crowdsale can continue to mint tokens up until the end time or the main cap being reached.

### Notable Warnings
No warnings were found in this contract.

### Concerns
No concerns with this contract.

### Recommendations
- Consider using SafeMath.mul and SafeMath.div for consistency:
    ```solidity
    122  uint256 returnAmount = extraTokens / currentDiscount();
    	---- and ----
    143  uint256 totalOwed = tokensRaised * 10000000 / 56666666;
    ````

## Scope
The primary goal of this audit is to ensure the token sale mechanisms in these contracts function smoothly and limit possible attack surfaces.

## Limitations

This audit makes no statements about the viability of Fynance's business proposition, the individuals involved in this business, or the regulatory bodies associated with the business.


This document was prepared by Steven Ireland for Fynance on 2017-12-03.
