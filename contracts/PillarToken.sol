pragma solidity ^0.4.11;

import './TeamAllocation.sol';
import './UnsoldAllocation.sol';
import './zeppelin/SafeMath.sol';
import './zeppelin/ERC20/StandardToken.sol';
import './zeppelin/ownership/Ownable.sol';
import './zeppelin/lifecycle/Pausable.sol';

/// @title PillarToken - Crowdfunding code for the Pillar Project
/// @author Parthasarathy Ramanujam, Gustavo Guimaraes, Ronak Thacker
contract PillarToken is StandardToken, Ownable {

    using SafeMath for uint;
    string public constant name = "PILLAR";
    string public constant symbol = "PLR";
    uint public constant decimals = 18;
    uint public totalSupply;

    TeamAllocation public teamAllocation;
    UnsoldAllocation public unsoldTokens;
    UnsoldAllocation public twentyThirtyAllocation;
    UnsoldAllocation public futureSaleAllocation;

    uint constant public minTokensForSale  = 32000000e18;

    uint constant public maxPresaleTokens             =  48000000e18;
    uint constant public totalAvailableForSale        = 528000000e18;
    uint constant public futureTokens                 = 120000000e18;
    uint constant public twentyThirtyTokens           =  80000000e18;
    uint constant public lockedTeamAllocationTokens   =  16000000e18;
    uint constant public unlockedTeamAllocationTokens =   8000000e18;

    address public unlockedTeamStorageVault = 0xF5aFd2285e071e1e8e415Ce9Af8641fdBF66410d;
    address public twentyThirtyVault = 0xF5aFd2285e071e1e8e415Ce9Af8641fdBF66410d;
    address public futureSaleVault = 0xF5aFd2285e071e1e8e415Ce9Af8641fdBF66410d;
    address unsoldVault;

    //Storage years
    uint constant coldStorageYears = 10;
    uint constant futureStorageYears = 3;

    uint totalPresale = 0;

    // Funding amount in ether
    uint public constant tokenPrice  = 0.0005 ether;

    // Multisigwallet where the proceeds will be stored.
    address public pillarTokenFactory;

    uint fundingStartBlock;
    uint fundingStopBlock;

    // flags whether ICO is afoot.
    bool fundingMode;

    //total used tokens
    uint totalUsedTokens;

    event Refund(address indexed _from,uint256 _value);
    event Migrate(address indexed _from, address indexed _to, uint256 _value);
    event MoneyAddedForRefund(address _from, uint256 _value,uint256 _total);

    modifier isNotFundable() {
      require(!fundingMode);
        _;
    }

    modifier isFundable() {
      require(fundingMode);
        _;
    }

    //@notice  Constructor of PillarToken
    //@param `_pillarTokenFactory` - multisigwallet address to store proceeds.
    //@param `_icedWallet` - Multisigwallet address to which unsold tokens are assigned
    constructor(address _pillarTokenFactory, address _icedWallet) {
      require(_pillarTokenFactory != address(0));
      require(_icedWallet != address(0));

      pillarTokenFactory = _pillarTokenFactory;
      totalUsedTokens = 0;
      totalSupply = 800000000e18;
      unsoldVault = _icedWallet;

      //allot 8 million of the 24 million marketing tokens to an address
      balances[unlockedTeamStorageVault] = unlockedTeamAllocationTokens;

      //allocate tokens for 2030 wallet locked in for 3 years
      futureSaleAllocation = new UnsoldAllocation(futureStorageYears,futureSaleVault,futureTokens);
      balances[address(futureSaleAllocation)] = futureTokens;

      //allocate tokens for future wallet locked in for 3 years
      twentyThirtyAllocation = new UnsoldAllocation(futureStorageYears,twentyThirtyVault,twentyThirtyTokens);
      balances[address(twentyThirtyAllocation)] = twentyThirtyTokens;

      fundingMode = false;
    }

    //@notice Fallback function that accepts the ether and allocates tokens to
    //the msg.sender corresponding to msg.value
    function() payable isFundable external {
      purchase();
    }

    //@notice function that accepts the ether and allocates tokens to
    //the msg.sender corresponding to msg.value
    function purchase() payable isFundable {
      require(block.number >= fundingStartBlock);
      require(block.number <= fundingStopBlock);
      require(totalUsedTokens < totalAvailableForSale);

      require (msg.value >= tokenPrice);

      uint numTokens = msg.value.div(tokenPrice);
      require(numTokens >= 1);
      //transfer money to PillarTokenFactory MultisigWallet
      pillarTokenFactory.transfer(msg.value);

      uint tokens = numTokens.mul(1e18);
      totalUsedTokens = totalUsedTokens.add(tokens);
      require(totalUsedTokens <= totalAvailableForSale);

      balances[msg.sender] = balances[msg.sender].add(tokens);

      //fire the event notifying the transfer of tokens
      emit Transfer(0, msg.sender, tokens);
    }

    //@notice Function reports the number of tokens available for sale
    function numberOfTokensLeft() constant returns (uint256) {
      uint tokensAvailableForSale = totalAvailableForSale.sub(totalUsedTokens);
      return tokensAvailableForSale;
    }

    //@notice Finalize the ICO, send team allocation tokens
    //@notice send any remaining balance to the MultisigWallet
    //@notice unsold tokens will be sent to icedwallet
    function finalize() isFundable onlyOwner external {
      require(block.number > fundingStopBlock);

      require(totalUsedTokens >= minTokensForSale);

      require(unsoldVault != address(0));

      // switch funding mode off
      fundingMode = false;

      //Allot team tokens to a smart contract which will frozen for 9 months
      teamAllocation = new TeamAllocation();
      balances[address(teamAllocation)] = lockedTeamAllocationTokens;

      //allocate unsold tokens to iced storage
      uint totalUnSold = numberOfTokensLeft();
      if(totalUnSold > 0) {
        unsoldTokens = new UnsoldAllocation(coldStorageYears,unsoldVault,totalUnSold);
        balances[address(unsoldTokens)] = totalUnSold;
      }

      //transfer any balance available to Pillar Multisig Wallet
      pillarTokenFactory.transfer(this.balance);
    }

    //@notice Function that can be called by purchasers to refund
    //@notice Used only in case the ICO isn't successful.
    function refund() isFundable external {
      require(block.number > fundingStopBlock);
      require(totalUsedTokens < minTokensForSale);

      uint plrValue = balances[msg.sender];
      require(plrValue != 0);

      balances[msg.sender] = 0;

      uint ethValue = plrValue.mul(tokenPrice).div(1e18);
      msg.sender.transfer(ethValue);
      emit Refund(msg.sender, ethValue);
    }

    //@notice Function used for funding in case of refund.
    //@notice Can be called only by the Owner
    function allocateForRefund() external payable onlyOwner returns (uint){
      //does nothing just accepts and stores the ether
      emit MoneyAddedForRefund(msg.sender,msg.value,this.balance);
      return this.balance;
    }

    //@notice Function to allocate tokens to an user.
    //@param `_to` the address of an user
    //@param `_tokens` number of tokens to be allocated.
    //@notice Can be called only when funding is not active and only by the owner
    function allocateTokens(address _to,uint _tokens) isNotFundable onlyOwner external {
      uint numOfTokens = _tokens.mul(1e18);
      totalPresale = totalPresale.add(numOfTokens);

      require(totalPresale <= maxPresaleTokens);

      balances[_to] = balances[_to].add(numOfTokens);
    }

    //@notice Function to unPause the contract.
    //@notice Can be called only when funding is active and only by the owner
    function unPauseTokenSale() onlyOwner isNotFundable external returns (bool){
      fundingMode = true;
      return fundingMode;
    }

    //@notice Function to pause the contract.
    //@notice Can be called only when funding is active and only by the owner
    function pauseTokenSale() onlyOwner isFundable external returns (bool){
      fundingMode = false;
      return !fundingMode;
    }

    //@notice Function to start the contract.
    //@param `_fundingStartBlock` - block from when ICO commences
    //@param `_fundingStopBlock` - block from when ICO ends.
    //@notice Can be called only when funding is not active and only by the owner
    function startTokenSale(uint _fundingStartBlock, uint _fundingStopBlock) onlyOwner isNotFundable external returns (bool){
      require(_fundingStopBlock > _fundingStartBlock);

      fundingStartBlock = _fundingStartBlock;
      fundingStopBlock = _fundingStopBlock;
      fundingMode = true;
      return fundingMode;
    }

    //@notice Function to get the current funding status.
    function fundingStatus() external constant returns (bool){
      return fundingMode;
    }
}
