pragma spragma solidity ^0.4.17;

import "browser/SafeMath.sol";


contract liquidDemocracy {
  using SafeMath for uint;

  /* times written as seconds since unix epoch*/
  /*end of delegate period*/
  uint public delegatePeriodEnd;
  /*end of vote period*/
  uint public votePeriodEnd;
  /*percentage needed to acheive successful vote*/
  uint public pctQuorum;
  /*limits number of delegates removed from original user*/
  uint public delegationDepth;

  /*possible IPFS hash of proposal metadata*/
  bytes32 public proposalMetaData;


  /*redundant voter registers solve for different major issues when each is used individually*/

  /*tracks user registration and single signup*/
  mapping (address => bool) internal registeredVotersMap;

  /*allows contract to iterate over voters to tally votes and follow delegation chains*/
  address[] internal registeredVotersArray;

  /*0 equals no vote, 1 equals yea, 2 equals nay, 3 equals delegated vote*/
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
    modifier isRegisteredVoter(address _userAddress) {
        require(_isRegisteredVoter(_userAddress) == true);
      _;
    }
    /*verifies delegate is valid*/
    modifier isValidDelegate(address _userAddress) {
      require(_isValidDelegate(_userAddress) == true);
      _;
    }
    /*verifies if vote is delegated*/
    modifier isVoteDelegated(address _userAddress) {
      require(_isVoteDelegated(_userAddress) == false);
      _;
    }

  function liquidDemocracy(
    uint _delegatePeriodEnd,
    uint _votePeriodEnd,
    uint _delegationDepth,
    uint _pctQuorum,
    bytes32 _proposalMetaData
    ) public {
      delegatePeriodEnd = _delegatePeriodEnd;
      votePeriodEnd = _votePeriodEnd;
      delegationDepth = _delegationDepth;
      pctQuorum = _pctQuorum;
      proposalMetaData = _proposalMetaData;

  }

  /*allows voter to register for proposal*/
  function registerVoter(address _userAddress)
  external
  {

    require(registeredVotersMap[_userAddress] == false);

    registeredVotersArray.push(_userAddress);
    registeredVotersMap[_userAddress] = true;

  }

  /*allows user to offer themselves as a delegate*/
  function becomeDelegate(address _userAddress)
  external
  isRegisteredVoter(_userAddress)
  {
    willingToBeDelegate[_userAddress] = true;
  }

  /*allows user to vote a value
  todo: add option validation(is this a valid vote)
  todo: and initialization(how do we set the valid votes)
  todo: rewrite tests for voting*/
  function vote(address _userAddress, uint _value)
  external
  isRegisteredVoter(_userAddress)
  votePeriodOpen()
  isVoteDelegated(_userAddress)
  {
    require(_value < 255);
    userVotes[_userAddress] = _value;

  }

  /* allows user to delegate their vote to another user who is a valid delegeate*/
  function delegateVote(address _userAddress, address _delegateAddress)
  external
  isRegisteredVoter(_userAddress)
  isValidDelegate(_delegateAddress)
  delegatePeriodOpen()
  {

    userToDelegate[_userAddress] = _delegateAddress;

  }

  /*allows user to read their vote or their delegate's vote
  returns users vote*/
  function readVote(address _userAddress, uint _recursionCount)
  public view
  returns (uint)
  {

    if(_recursionCount > delegationDepth){
        return 0;
    }

    if (userToDelegate[_userAddress] != 0x0) {
      return readVote(userToDelegate[_userAddress], _recursionCount + 1);
    } else {
      return userVotes[_userAddress];
    }
  }

  function readEndVoter(address _userAddress, uint _recursionCount) public view returns(address){

    if(_recursionCount > delegationDepth){
     return 0x0;
    }

    if (userToDelegate[_userAddress] != 0x0) {
      return readEndVoter(userToDelegate[_userAddress], _recursionCount + 1);
    } else {
      return _userAddress;
    }
  }

  /*allows user to revoke their delegation if they disagree with delegates vote*/
  function revokeDelegation(address _userAddress)
  public
  isRegisteredVoter(_userAddress)
  votePeriodOpen()
  {

    userVotes[_userAddress] = 0;
    userToDelegate[_userAddress] = 0;

  }


  //todo: how to handle final decision and runoff conditions
  function finalTally() public{

    uint totalVotes;
    uint emptyVotes;
    uint[256] memory votes;

    (votes, totalVotes, emptyVotes) = tally();


    if ((totalVotes * 100) / (registeredVotersArray.length) < pctQuorum) {
      //decision = 0;
    }
    else{
        /*
        //todo: threshold
        for (i = 0; i < _votes.length; i++){
            if(decision == 0 || votes[i] > decisionVotes){
                decision = i;
                decisionVotes = votes[i];
            }
        }
        */
    }

  }

  /*allows user tally votes at */
  function tally()
  public view
  returns (uint[256] _votes, uint _totalVotes, uint _emptyVotes)
  {

    //todo: how to handle vote validation and initialization
    for (uint i = 0; i < registeredVotersArray.length; i++){
      uint vote = readVote(registeredVotersArray[i], 0);
      _votes[vote + 1]++;

      if(vote > 0){
          _totalVotes++;
      } else {
          _emptyVotes++;
      }

    }



    return (_votes, _totalVotes, _emptyVotes);
  }

  /*these addtional functions allow me to test contract. would remove bottom two for production and implement in modifier*/

  function _isVoteDelegated(address _userAddress)
  view
   internal
   returns (bool _voteStatus){
    if (userVotes[_userAddress] == 3) {
      return true;
    } else {
      return false;
    }
  }

  function _isRegisteredVoter(address _userAddress)
  view
   public
   returns (bool _voterRegistration){
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
