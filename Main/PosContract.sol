pragma solidity ^0.4.18;
import '../Main/FynanceToken.sol';
import '../Ownership/Ownable.sol';
import '../Math/SafeMath.sol';

/**
 * @title Proof-of-Stake
 * @dev This contract will accept Ether by a company and keep track of and disburse amounts owed to users.
**/ 

contract PosContract is Ownable {
    using SafeMath for uint256;
    
    FynanceToken token;
    uint256 public lastWithdraw; // Last deposit the owner withdrew from (cuts down on loop gas).
    
    // User => Amount of combined Ether owed from deposits.
    mapping (address => uint256) dividendOwed;
    
    // User => Last "deposits" index committed.
    mapping (address => uint256) lastCommitted;

    // Array of each deposit that has been made by the owners.
    Deposit[] public deposits;

    struct Deposit {
        uint256 depositTime; // Timestamp when deposit was made.
        uint256 depositAmount; // Wei amount of deposit.
        uint256 amountLeft; // Amount is lowered after each withdrawal (so owners can withdraw old funds). 
        uint256 currentSupply; // The current token supply (used to find ownership % at time of deposit).
    }
    
    // Every time owners deposit ether into the contract an event is emitted.
    event EtherDeposit(address indexed from, uint256 indexed amount, uint256 indexed blockTime, uint256 currentSupply);
    
    /**
     * @dev We need token address to allow only token to withdraw to users and to check balances.
     * @param _token Address of the token contract.
    **/
    function PosContract(address _token)
      public
    {
        token = FynanceToken(_token);
    }

    /**
     * @dev Users call claimDividend on token which calls this to withdraw their owed Ether.
     * @param _user The address of the user owed Ether.
    **/
    function withdrawDividend(address _user)
      external
    returns (bool success)
    {
        assert(calculateDividend(_user));
        
        uint256 owed = dividendOwed[_user];
        dividendOwed[_user] = 0;
        _user.transfer(owed);
        
        success = true;
    }
    
    /**
     * @dev Used by us to deposit Ether into this contract.
    **/
    function ownerDeposit()
      external
      payable
    {
        uint256 totalSupply = token.totalSupply();
        Deposit memory newDeposit = Deposit(block.timestamp, msg.value, msg.value, totalSupply);
        deposits.push(newDeposit);
    
        EtherDeposit(msg.sender, msg.value, block.timestamp, totalSupply);
    }
    
    /**
     * @dev Owner uses withdraw to take out old, unclaimed funds.
    **/
    function ownerWithdraw()
      external
      onlyOwner
    {
        uint256 ownerAllowance;
        for (uint256 i = lastWithdraw; i < deposits.length; i++) {
            if (now >= deposits[i].depositTime.add(12 weeks)) {
                ownerAllowance = ownerAllowance.add(deposits[i].amountLeft);
                deposits[i].amountLeft = 0;
                lastWithdraw = i;
            } else break;
        }
        owner.transfer(ownerAllowance);
    }
    
    /**
     * @dev User can call to update and check their dividend owed.
     * @param _user The address to check dividend owed for.
    **/
    function checkDividend(address _user)
      external
    returns (uint256 dividend)
    {
        assert(calculateDividend(_user));
        dividend = dividendOwed[_user];
    }
    
    /**
     * @dev Calculates the Ether dividend owed to this user. Start from the last time
     * @dev balance was changed, calculate how much of each deposit since then is owed.
     * @param _user The address whose reward is being calculated.
    **/
    function calculateDividend(address _user)
      public
    returns (bool success)
    {
        uint256 balance = token.balanceOf(_user);
        uint256 dividend;
        
        for (uint256 i = lastCommitted[_user]; i < deposits.length; i++) {
            if (deposits[i].amountLeft == 0) continue;
            
            uint256 depositOwed = (balance.mul(deposits[i].depositAmount)).div(deposits[i].currentSupply);
            dividend = dividend.add(depositOwed);
            deposits[i].amountLeft = deposits[i].amountLeft.sub(depositOwed);
        }

        if (deposits.length > 0) lastCommitted[_user] = deposits.length;
        dividendOwed[_user] = dividendOwed[_user].add(dividend);
        success = true;
    }
    
}
