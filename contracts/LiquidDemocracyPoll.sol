pragma solidity ^0.4.17;

import "./LDPollInterface.sol";
import "./LDForumInterface.sol";


contract LiquidDemocracyPoll is LDPollInterface {
  /*contract LiquidDemocracyPoll {*/


  /* times written as seconds since unix epoch*/
  /*end of delegate period*/
  uint public delegatePeriodEnd;
  /*end of vote period*/
  uint public votePeriodEnd;
  /*percentage of registered voters rsponding needed to acheive valid poll*/
  uint public pctQuorum;
  /*percentage of votes toward a particular option needed to acheive successful option*/
  uint public pctThreshold;
  /*limits number of delegates removed from original user*/
  uint public delegationDepth;
  /*possible IPFS hash of proposal metadata*/
  bytes32 public proposalMetaData;
  /*256 bit array that holds the validity of each possible vote option. Options are referenced and defined in poll metadata. */
  uint public validVoteOptions;

  uint public pollId;
  address public forumAddress;
  uint public topic;


/*want to think about not having users stand up as delegates, but allow anyone to delegate to anyone*/


  /*redundant voter registers solve for different major issues when each is used individually*/

  /*tracks user registration and single signup*/
  mapping (address => bool) internal registeredVotersMap;

  /*allows contract to iterate over voters to tally votes and follow delegation chains*/
  address[] internal registeredVotersArray;

  /*0 equals no vote, other values will equate to those set in vote initialization*/
  mapping (address => uint) public userVotes;

  /*points to voter delegate*/
  mapping (address => address) public userToDelegate;

  /* mapping of valid delegates */
  mapping (address => bool) public willingToBeDelegate;


  /*verifies delegate period open*/
  modifier delegatePeriodOpen(){
    require(block.timestamp < delegatePeriodEnd);
    _;
  }

  /*verifies vote period open*/
  modifier votePeriodOpen(){
    require(block.timestamp < votePeriodEnd);
    _;
  }

  /*would clean and reduce modifiers and helper functions for production*/
  /*verifies voter is registered*/
    modifier isRegisteredVoter() {
        require(_isRegisteredVoter(msg.sender) == true);
      _;
    }
    /*verifies delegate is valid*/
    modifier isValidDelegate(address _delegateAddress) {
      require(_isValidDelegate(_delegateAddress) == true);
      _;
    }
    /*verifies if vote is delegated*/
    modifier isVoteDelegated() {
      require(_isVoteDelegated(msg.sender) == false);
      _;
    }
    /*verifies if vote is delegated*/
    modifier isValidVoteOption(uint _vote) {
      require(_vote <= validVoteOptions);
      _;
    }
    modifier isValidChainDepthAndNonCircular() {
      bool bValid;
      (bValid,,) =_isValidChainDepthAndNonCircular(msg.sender, 0);
      require(bValid);
      _;
    }
    modifier isVoterDelegateAndDelegatePeriodOpen() {
      if (willingToBeDelegate[msg.sender] == true) {
        require(block.timestamp < delegatePeriodEnd);
      }
      _;
    }

/**********/
    /*NEED TO ADD EVENTS*/
/***********/

  function LiquidDemocracyPoll(
    uint _delegatePeriodEnd,
    uint _votePeriodEnd,
    uint _delegationDepth,
    uint _pctQuorum,
    uint _pctThreshold,
    bytes32 _proposalMetaData,
    uint _validVoteOptions,
    uint _pollId,
    address _forumAddress,
    uint _topic
    ) public {
      delegatePeriodEnd = _delegatePeriodEnd;
      votePeriodEnd = _votePeriodEnd;
      delegationDepth = _delegationDepth;
      pctQuorum = _pctQuorum;
      pctThreshold = _pctThreshold;
      proposalMetaData = _proposalMetaData;
      validVoteOptions = _validVoteOptions;
      pollId = _pollId;
      forumAddress = _forumAddress;
      topic = _topic;
  }

  /*allows voter to register for poll*/
  function registerVoter()
  external
  votePeriodOpen
  {

    require(registeredVotersMap[msg.sender] == false);

    registeredVotersArray.push(msg.sender);
    registeredVotersMap[msg.sender] = true;

  }

  /*allows user to offer themselves as a delegate*/
  function becomeDelegate()
  external
  isRegisteredVoter
  delegatePeriodOpen
  {
    willingToBeDelegate[msg.sender] = true;
  }

  /*allows user to vote a value*/
  function vote(uint _value)
  external
  isRegisteredVoter
  isVoterDelegateAndDelegatePeriodOpen
  isValidVoteOption(_value)
  votePeriodOpen
  {
    userVotes[msg.sender] = _value;
  }

  /* allows user to delegate their vote to another user who is a valid delegeate*/
  function delegateVote(address _delegateAddress)
  external
  isRegisteredVoter
  isValidDelegate(_delegateAddress)
  isValidChainDepthAndNonCircular
  delegatePeriodOpen
  {
    userToDelegate[msg.sender] = _delegateAddress;
  }

  /*can refactor these functions to be one
  or just refactor to have each do something different, not DRY currently
  */

  /*allows user to read their vote or their delegate's vote
  returns users vote*/
  function readVoteAndEndVoter(address _userAddress, uint _recursionCount)
  public
  view
  returns (uint _voteValue, address _endVoterAddress)
  {

    if (userVotes[_userAddress] != 0) {
      _voteValue = userVotes[_userAddress];
      _endVoterAddress = _userAddress;
      return;
    }

    if (_recursionCount > delegationDepth){
      _voteValue = 0;
      _endVoterAddress = _userAddress;
      return;
    }

    address forumDelegate = LDForumInterface(forumAddress).readEndDelegateForTopic(_userAddress, topic, 0);

    if (userToDelegate[_userAddress] != 0x0) {
      return readVoteAndEndVoter(userToDelegate[_userAddress], _recursionCount + 1);
    } else if (forumDelegate != 0x0) {
      return readVoteAndEndVoter(forumDelegate, _recursionCount + 1);
    } else {
      _voteValue = 0;
      _endVoterAddress = _userAddress;
      return;
    }
  }

  /*function readEndVoter(address _userAddress, uint _recursionCount)
  public
  view
  returns (address)
  {

    address forumDelegate = LDForumInterface(forumAddress).readEndDelegateForTopic(_userAddress, topic, 0);

    if (userToDelegate[_userAddress] == 0x0 && forumDelegate == _userAddress) {
      return _userAddress;
    }

    if (_recursionCount > delegationDepth){
     return 0x0;
    }

    if (userToDelegate[_userAddress] != 0x0) {
      return readEndVoter(userToDelegate[_userAddress], _recursionCount + 1);
    } else if (forumDelegate != 0x0) {
      return readEndVoter(forumDelegate, _recursionCount + 1);
    } else {
      return _userAddress;
    }
  }*/


  /*allows user to read user they delegated their vote to*/
  function readDelegate(address _userAddress)
  external
  view
  returns (address _delegateAddress)
  {
    address forumDelegate = LDForumInterface(forumAddress).readDelegateForTopic(_userAddress, topic);

    if (userToDelegate[_userAddress] != 0x0) {
      return userToDelegate[_userAddress];
    } else if (forumAddress != 0x0) {
      return forumDelegate;
    } else {
      return 0x0;
    }

  }

  /*allows user to revoke their delegation if they disagree with delegates vote*/
  function revokeDelegationForPoll()
  public
  isRegisteredVoter
  votePeriodOpen
  {
    userToDelegate[msg.sender] = 0x0;
  }

  /**/
  /**/
  /*Need to implement onlyVoter function!!!!!!!!!!

    must implement controls so that only the msg.sender can can their own data, no other actor should be able to change data.
  /
  /**/
  /**/

  function withdrawDirectVote()
  public
  isRegisteredVoter
  votePeriodOpen
  {
    userVotes[msg.sender] = 0;
  }


/*figure out how to handle ties
  return array of winners, if array is length 1, easy solution.
  if tied, auto-generate run-off poll
*/

  //todo: how to handle final decision and runoff conditions
  /*if we can make this a view function, that would be ideal*/
  function finalDecision()
  public
  view
  returns (uint _finalDecision, uint _finalDecisionTally)
  {

    uint totalVotes;
    uint emptyVotes;
    uint[256] memory _tallyResults;

    (_tallyResults, totalVotes, emptyVotes) = tally();


    if (registeredVotersArray.length == 0 || (totalVotes * 100) / (registeredVotersArray.length) < pctQuorum) {
      _finalDecision = 0;
      _finalDecisionTally = 0;
      return;
    } else {

      uint highestVoteHold = 0;
      uint highestVoteValueHold = 0;

        for (uint i = 0; i < _tallyResults.length; i++) {
          if (_tallyResults[i] > highestVoteValueHold) {
            highestVoteValueHold = _tallyResults[i];
            highestVoteHold = i;
          }
        }

        if (((highestVoteValueHold * 100) / totalVotes) > pctThreshold) {
          _finalDecision = highestVoteHold;
          _finalDecisionTally = highestVoteValueHold;
          return;
        } else {
          _finalDecision = 0;
          _finalDecisionTally = 0;
          return;
        }
    }
  }

/* recording votes/delegatoins as they happen vs. tallyin at the end, may be more expensive  upfront, but allows outcome to be actionable on chain, because end tally function doesnt run out of gas. */

/*could have gas conscious tally function that run multiple times.*/


  /*allows user tally votes at */
  function tally()
  public
  view
  returns (uint[256] _votes, uint _totalVotes, uint _emptyVotes)
  {

    /*could point to registered voters in forum, instead of poll*/

    //todo: how to handle vote validation and initialization
    for (uint i = 0; i < registeredVotersArray.length; i++){
      uint vote;
    (vote,)  = readVoteAndEndVoter(registeredVotersArray[i], 0);
      _votes[vote]++;

      if(vote > 0){
          _totalVotes++;
      } else {
          _emptyVotes++;
      }
    }
    return (_votes, _totalVotes, _emptyVotes);
  }


function changeForumAddress(address _newForumAddress)
  public

{
  forumAddress = _newForumAddress;
  /*event*/
}

/*Could refactor to just use uints. why the complicated bit math?*/

 /*function _isValidVoteOption(uint _vote) public view returns(bool){
      byte MyByte = validVoteArray[_vote / 8];
      uint MyPosition = 7 - (_vote % 8);

     return  2**MyPosition == uint8(MyByte & byte(2**MyPosition));
 }*/

 /**/
 /**/
 /*Could there be circular delegation if poll and forum delegations are separate?
                 Must Check*/
 /**/
 /**/

 function _isValidChainDepthAndNonCircular(address _userAddress, uint _recursionCount)
  public
  view
  returns(bool _valid, bool _vDepth, bool _vCircle)
 {

   if(_recursionCount > delegationDepth){
     _vDepth = true;
     _valid = false;
     return;
   }

      address forumDelegate = LDForumInterface(forumAddress).readDelegateForTopic(_userAddress, topic);

   if (userToDelegate[_userAddress] != 0x0 || forumDelegate != 0x0) {
     if (userToDelegate[_userAddress] == _userAddress || forumDelegate == _userAddress) {
       _valid = false;
       _vCircle = true;
       return;
     }
     return _isValidChainDepthAndNonCircular(userToDelegate[_userAddress], _recursionCount + 1);
   } else {
     _valid = true;
     return;
   }
 }

  /*these addtional functions allow me to test contract. would remove bottom two for production and implement in modifier*/

  function _isVoteDelegated(address _userAddress)
   view
   internal
   returns (bool _voteStatus)
  {

     address forumDelegate = LDForumInterface(forumAddress).readDelegateForTopic(_userAddress, topic);

    if (userToDelegate[_userAddress] != 0x0 || forumDelegate != 0x0) {
      return true;
    } else {
      return false;
    }
  }

  function _isRegisteredVoter(address _userAddress)
   view
   public
   returns (bool _voterRegistration)
  {
    if (registeredVotersMap[_userAddress] == true) {
      return true;
    } else {
      return false;
    }
  }

  function _isValidDelegate(address _userAddress)
  view
   public
   returns (bool _delegateStatus){
    if (willingToBeDelegate[_userAddress] == true) {
      return true;
    } else {
      return false;
    }
  }

  function () external payable {
    revert();
  }

}
