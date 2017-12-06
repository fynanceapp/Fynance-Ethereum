# Fynance-Ethereum
Fynance-Ethereum is a set of contracts that enables holders of the Fynance token (FYG) to receive dividends, depending on how many tokens they hold, when the owners deposit Ether to disburse.
</br>
</br>
<h2>Token</h2>
The token contract is a fairly normal ERC20 contract except that every time a user's balance changes, the proof-of-stake contract is notified and the user's owed balance from the proof-of-stake contract is updated.
</br>
</br>
<h2>Proof-of-Stake</h2>
This contract keeps track of all deposits of Ether made by the owners and, when a user's token balance is changed, calculates how much Ether is owed to the user for the amount of coins they were previously holding. The contract can then be used directly or from the token contract by a user to withdraw owed funds.
</br>
</br>
<h2>Crowdsale</h2>
This contract is written to allow for both the individual investor and institutional investor crowdsale contracts to be launched from it. The individual investor contract will include a presale and discounts for different periods whereas the institutional investor contract will have no presale, a minimum purchase value (of 30 Ether), and a consistent discount (1280 tokens per Ether). These contracts will also have a cap of 67 million and 100 million respectively. They are separate instead of both in one because they have different caps and different time periods, making splitting them up simpler and safer.
