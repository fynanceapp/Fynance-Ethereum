pragma solidity ^0.4.18;
import '../Main/FynanceToken.sol';
import '../Ownership/Ownable.sol';
import '../Math/SafeMath.sol';

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract Crowdsale is Ownable {
  using SafeMath for uint256;

  // The token being sold
  FynanceToken public token;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;
  uint256 public presaleStartTime;
  uint256 public presaleEndTime;

  // address where funds are collected
  address public wallet;

  // amount of raised money in wei
  uint256 public weiRaised;
  
  // amount of raised tokens (used for discount tiers + cap)
  uint256 public tokensRaised;
  
  // Amount of tokens that have been withdrawn by the owners (15% of tokens sold total)
  uint256 public tokensWithdrawn;
  
  // The maximum wei value allowed for a purchase.
  uint256 public maximumValue;
  
  // We have to have this so the big investor contract can require 30 Ether.
  uint256 public minimumValue;
  
  // decimals of the Fynance Germany token
  uint256 public decimals = (10 ** 18);
  
  // maximum amount of TOKENS that may be sold
  uint256 public cap;
  uint256 public presaleCap;
  
  // Maximum tokens that can be sold in each discount tier
  // If presale does not hit cap, first round is longer than 5 million tokens
  uint256 public DISCOUNT_TIER_ONE = 7000000 * decimals;
  uint256 public DISCOUNT_TIER_TWO = 17000000 * decimals;
  uint256 public DISCOUNT_TIER_THREE = 37000000 * decimals;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   * @param totalWeiRaised The total amount of wei that has been raised -- used for ticker on website
   * @param totalTokensRaised The total amount of tokens that have been raised -- used for ticker on website
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount, uint256 totalWeiRaised, uint256 totalTokensRaised);

  /**
   * @dev Defines presale times, crowdsale times, caps, and minimum value.
   * @dev Presale times, cap, and minimumValue can be neglected to fit the crowdsale's needs.
   * @param _startTime The time the main crowdsale begins.
   * @param _endTime The time the main crowdsale ends.
   * @param _presaleStartTime The time the presale, if there is one, begins.
   * @param _presaleEndTime The time the presale, if there is one, ends.
   * @param _wallet The wallet that all Ether and owner tokens will be sent to.
   * @param _cap The main crowdsale cap -- IN FULL TOKENS, NOT WEI!
   * @param _presaleCap The presale cap -- IN FULL TOKENS, NOT WEI!
   * @param _minimumValue The lowest value, if there is one, that must be bought -- in Ether wei.
   * @param _maximumValue The highest value allowed to be sent (must have one).
  **/
  function Crowdsale(uint256 _startTime, uint256 _endTime, uint256 _presaleStartTime, uint256 _presaleEndTime, address _wallet, uint256 _cap, uint256 _presaleCap, uint256 _minimumValue, uint256 _maximumValue) {
    require(_presaleEndTime >= _presaleStartTime);
    require(_startTime > _presaleEndTime);
    // Presale may be 0 to allow for no presale
    require(_startTime >= now);
    require(_endTime > _startTime);
    require(_wallet != address(0));
    require(_cap > 0);
    // Presale cap may be 0 to allow for no presale
    require(_maximumValue > 0);
    
    startTime = _startTime;
    endTime = _endTime;
    presaleStartTime = _presaleStartTime;
    presaleEndTime = _presaleEndTime;
    wallet = _wallet;
    cap = _cap * decimals;
    presaleCap = _presaleCap * decimals;
    minimumValue = _minimumValue;
    maximumValue = _maximumValue;
  }

  // fallback function can be used to buy tokens
  function () payable {
    buyTokens(msg.sender);
  }

/** ******************************* External ********************************* **/

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != address(0));
    require(validPurchase());

    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 tokens = weiAmount.mul(currentDiscount());
    
    // current cap is used to ensure presale is capped at the right limit
    uint256 currentCap;
    if (withinPresale()) currentCap = presaleCap;
    else currentCap = cap;
    
    // if user is trying to contribute more than cap, return the extra
    if (tokensRaised.add(tokens) > currentCap) {
        uint256 extraTokens = (tokensRaised.add(tokens)).sub(currentCap);
        uint256 returnAmount = extraTokens.div(currentDiscount());
        
        tokens = tokens.sub(extraTokens);
        weiAmount = weiAmount.sub(returnAmount);
        
        msg.sender.transfer(returnAmount);
    }   
    
    // update state
    weiRaised = weiRaised.add(weiAmount);
    tokensRaised = tokensRaised.add(tokens);
    
    assert(token.mint(beneficiary, tokens));
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens, weiRaised, tokensRaised);

    wallet.transfer(weiAmount);
  }
  
  // Owners can withdraw their 15% of tokens throughout the crowdsale
  function ownerWithdraw() external onlyOwner {
    // Dividing current amount by 5.66666 should give us 15% of the final amount
    uint256 totalOwed = tokensRaised.mul(10000000).div(56666666);
    uint256 owedLeft = totalOwed.sub(tokensWithdrawn);
    
    tokensWithdrawn = tokensWithdrawn.add(owedLeft);
    assert(token.mint(wallet, owedLeft));
  }
  
  // May set the token address ONCE
  function setToken(address _token) external onlyOwner {
    require(address(token) == 0);
    token = FynanceToken(_token);
  }
  
/** ******************************* Constant ********************************* **/

  // get current rate of tokens per Ether
  // @return The number of tokens per Ether at this tier
  function currentDiscount() public constant returns (uint256) {
    if (msg.value >= 30 ether) return 1280;
    else if (withinPresale()) return 1280;
    else if (tokensRaised < DISCOUNT_TIER_ONE) return 1180;
    else if (tokensRaised < DISCOUNT_TIER_TWO) return 1100;
    else if (tokensRaised < DISCOUNT_TIER_THREE) return 1050;
    else return 1000;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public constant returns (bool) {
    bool capReached = tokensRaised >= cap;
    bool timeReached = now > endTime;
    return capReached || timeReached;
  }

  // check if the current time is during the presale period
  function withinPresale() public constant returns (bool) {
    bool presalePeriod = now >= presaleStartTime && now <= presaleEndTime;    
    bool presaleSold = tokensRaised < presaleCap;
    return presalePeriod && presaleSold;
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool enoughValue = msg.value >= minimumValue && msg.value <= maximumValue;
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool withinCap = tokensRaised < cap;
    return (withinPeriod || withinPresale()) && nonZeroPurchase && withinCap && enoughValue;
  }

}
