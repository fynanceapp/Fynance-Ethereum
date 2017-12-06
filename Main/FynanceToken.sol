pragma solidity ^0.4.18;
import '../Main/PosContract.sol';
import '../Ownership/Ownable.sol';
import '../Math/SafeMath.sol';

/**
 * @title Fynance Germany Token
 * @dev ERC20 with a system to update owed dividends on the PoS contract so we may issue dividends.
**/

contract FynanceToken is Ownable {
    using SafeMath for uint256;
    
    PosContract public pos;
    
    string public constant symbol = "FYG";
    string public constant name = "Fynance Germany";
    uint8 public constant decimals = 18;

    uint256 _totalSupply;

    // Crowdsale address needed for minting.
    address crowdsale;
    // The second crowdsale for institutional investors.
    address crowdsaleTwo;

    // Balances for each account
    mapping(address => uint256) balances;

    // Owner of account approves the transfer of an amount to another account
    mapping(address => mapping (address => uint256)) allowed;

    event Transfer(address indexed _from, address indexed _to, uint indexed _amount);
    event Approval(address indexed _from, address indexed _spender, uint indexed _amount);
    event Mint(address indexed _to, uint256 indexed _amount);

    /**
     * @dev Set owner and beginning balance.
    **/
    function FynanceToken(address _crowdsale, address _crowdsaleTwo)
      public
    {
        crowdsale = _crowdsale;
        crowdsaleTwo = _crowdsaleTwo;
    }

    /**
     * @dev Return total supply of token.
    **/
    function totalSupply() 
      external
      constant 
    returns (uint256) 
    {
        return _totalSupply;
    }

    /**
     * @dev Return balance of a certain address.
     * @param _owner The address whose balance we want to check.
    **/
    function balanceOf(address _owner)
      external
      constant 
    returns (uint256) 
    {
        return balances[_owner];
    }

    /**
     * @dev Transfers coins from one address to another.
     * @param _to The recipient of the transfer amount.
     * @param _amount The amount of tokens to transfer.
    **/
    function transfer(address _to, uint256 _amount) 
      external
    returns (bool success)
    {
        // These calculate based off old balance so they must come first.
        assert(pos.calculateDividend(msg.sender));
        assert(pos.calculateDividend(_to));
        
        // Will throw with insufficient balance
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        
        Transfer(msg.sender, _to, _amount);
        success = true;
    }

    /**
     * @dev An allowed address can transfer tokens from another's address.
     * @param _from The owner of the tokens to be transferred.
     * @param _to The address to which the tokens will be transferred.
     * @param _amount The amount of tokens to be transferred.
    **/
    function transferFrom(address _from, address _to, uint _amount)
      external
    returns (bool success)
    {
        assert(pos.calculateDividend(_from));
        assert(pos.calculateDividend(_to));

        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        balances[_from] = balances[_from].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        
        Transfer(_from, _to, _amount);
        success = true;
    }

    /**
     * @dev Approves a wallet to transfer tokens on one's behalf.
     * @param _spender The wallet approved to spend tokens.
     * @param _amount The amount of tokens approved to spend.
    **/
    function approve(address _spender, uint256 _amount) 
      external
    {
        require(balances[msg.sender] >= _amount);
        require(allowed[msg.sender][_spender] == 0 || _amount == 0);
        
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
    }

    /**
     * @dev Allowed amount for a user to spend of another's tokens.
     * @param _owner The owner of the tokens approved to spend.
     * @param _spender The address of the user allowed to spend the tokens.
    **/
    function allowance(address _owner, address _spender) 
      external
      constant 
    returns (uint256) 
    {
        return allowed[_owner][_spender];
    }
    
/** ***************************** PoS Function ********************************* **/
    
    /**
     * @dev Contact PosContract to withdraw dividend.
    **/
    function claimDividend()
      external
    {
        assert(pos.withdrawDividend(msg.sender));
    }
    
/** ************************** Only Owner/Crowdsale **************************** **/
    
    /**
     * @dev Used by the crowdsale contract during crowdsale to mint coins.
     * @dev This must never be able to be used after crowdsale!
     * @param _to The address to mint coins to.
     * @param _amount The amount of coins to mint to the address.
    **/
    function mint(address _to, uint256 _amount)
      external
    returns (bool success)
    {
        require(msg.sender == crowdsale || msg.sender == crowdsaleTwo);
        assert(pos.calculateDividend(_to));
        
        balances[_to] = balances[_to].add(_amount);
        _totalSupply = _totalSupply.add(_amount);
        
        Mint(_to, _amount);
        success = true;
    }
    
    /**
     * @dev Used if the owner needs to change out the PoS contract.
     * @param _newPos The address of the new PoS contract.
    **/
    function changePos(address _newPos)
      external
      onlyOwner
    {
        pos = PosContract(_newPos);
    }
    
}
