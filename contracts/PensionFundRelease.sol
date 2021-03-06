pragma solidity ^0.4.10;

import "zeppelin-solidity/contracts/token/SimpleToken.sol";
import "zeppelin-solidity/contracts/token/ERC20Basic.sol";


contract PensionFundRelease {
    address[] public validators;
    address public worker;
    uint8 public firstPaymentPercent;
    uint public firstPaymentTime;
    uint public reccurentPaymentInterval;
    uint8 public reccurentPaymentPercent;
    ERC20Basic public roots;

    struct Vote {
        bool approve;
        address validator;
        string justification;
    }

    mapping (address => uint) public voteIndex;
    Vote[] public votes;
    bool public firtPaymentReleased = false;

    event Voted(bool approve, address validator, string justification);
    event Released(uint amount, address worker);

    function PensionFundRelease(
        address[] _validators,
        address _worker,
        uint8 _firstPaymentPercent,
        uint _firstPaymentTime,
        uint _reccurentPaymentInterval,
        uint8 _reccurentPaymentPercent,
        address _rootsAddress
    ) {
        require(_validators.length > 0);
        require(_worker != 0x0);
        require(_firstPaymentPercent <= 100);
        require(_reccurentPaymentPercent <= 100);

        validators = _validators;
        worker = _worker;
        firstPaymentPercent = _firstPaymentPercent;
        firstPaymentTime = _firstPaymentTime;
        reccurentPaymentInterval = _reccurentPaymentInterval;
        reccurentPaymentPercent = _reccurentPaymentPercent;
        roots = ERC20Basic(_rootsAddress);

        votes.push(Vote(false, 0x0, "")); //first dummy vote
    }

    //ensure that only validator can perform the action
    modifier onlyValidator() {
        bool isValidator = false;
        for (uint i = 0; i < validators.length; i++) {
            isValidator = isValidator || (msg.sender == validators[i]);
        }
        require(isValidator);
        _;
    }

    //vote for the fund release or burn
    function vote(bool approve, string justification) onlyValidator returns (uint index) {
        index = voteIndex[msg.sender];
        Vote memory vote = Vote(approve, msg.sender, justification);
        if (index == 0) {
            index = votes.length;
            voteIndex[msg.sender] = index;
            votes.push(vote);
        } else {
            votes[index] = vote;
        }

        Voted(approve, msg.sender, justification);
    }

    // check wether validators have approved the release
    function isReleaseApproved() constant returns (bool approved) {
        uint num = 0;
        for (uint i = 1; i < votes.length; i++) { //skip dummy vote
            if (votes[i].approve)
                num++;
        }

        return num == validators.length;
    }

    // check wether validators have decided to burn the fund
    function isBurnApproved() constant returns (bool approved) {
        uint num = 0;
        for (uint i = 1; i < votes.length; i++) { //skip dummy vote
            if (!votes[i].approve)
                num++;
        }

        return num == validators.length;
    }

    // calculate the amount of payment
    function getPaymentAmount() constant returns (uint amount) {
        if (!firtPaymentReleased) 
            return balance() * 100 / firstPaymentPercent;
        
        return 0;
    }

    // get current fund balance in ROOTs
    function balance() constant returns (uint amount) {
        return roots.balanceOf(this);
    }

    // release the fund
    function releaseRoots() returns (uint releasedAmount) {
        require(isReleaseApproved());
        require(now > firstPaymentTime);

        releasedAmount = getPaymentAmount();
        if (releasedAmount > 0) {
            firtPaymentReleased = true;
            roots.transfer(worker, releasedAmount);
            Released(releasedAmount, worker);
        }
    }
}