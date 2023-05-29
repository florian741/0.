// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

// to be preferred to require (because it's more economical with gas)
error ProposalDoublon();
error ProposalsRegistrationStartedUnstarted();

contract Voting is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // ---------------------  start of personal code  ------------------

    mapping(address => Voter) public voters;
    WorkflowStatus public currentWorkflow;
    Proposal[] public proposals;

    // Function for registering a set of addresses authorized to vote (admin only)
    function addSetOfProposals(
        string[] memory _proposalNames
    ) external onlyOwner {

        if (currentWorkflow != WorkflowStatus.ProposalsRegistrationStarted) {
            revert ProposalsRegistrationStartedUnstarted();
        }

        for (uint i = 0; i < _proposalNames.length; i++) {
            proposals.push(
                Proposal({description: _proposalNames[i], voteCount: 0})
            );
        }
    }

    // Function to add a single additional address to the vote (admin only)
    function addVoters(address[] memory _voters) external onlyOwner {
        for (uint i = 0; i < _voters.length; i++) {
            voters[_voters[i]].isRegistered = true;
            emit VoterRegistered(_voters[i]);
        }
    }

    // Function to activate the right to submit a proposal (admin only)
    function startProposalsRegistration() external onlyOwner {
        require(
            currentWorkflow == WorkflowStatus.RegisteringVoters,
            "Voters must first be registered"
        );

        currentWorkflow = WorkflowStatus.ProposalsRegistrationStarted;

        emit WorkflowStatusChange(
            WorkflowStatus.RegisteringVoters,
            WorkflowStatus.ProposalsRegistrationStarted
        );
    }

    // Function for saving a proposal (in the proposal table)
    function addAProposal(string memory _proposalName) external {
        require(
            currentWorkflow == WorkflowStatus.ProposalsRegistrationStarted,
            "Proposal registration session must be launched"
        );
        require(
            voters[msg.sender].isRegistered,
            "Voters must be registered"
        );

        proposals.push(Proposal({description: _proposalName, voteCount: 0}));
    }

    // Bonus function (costly in terms of gas) which adds the rejection of duplicate proposals to the previous function.
    function addAProposalSansDoublon(string memory _proposalName) external {
        // replication to save gas
        Proposal[] memory proposalsReplique = proposals;

        for (uint i = 0; i < proposalsReplique.length; i++) {
            if (
                keccak256(abi.encodePacked(proposalsReplique[i].description)) ==
                keccak256(abi.encodePacked(_proposalName))
            ) {
                revert ProposalDoublon();
            }
        }
        require(
            currentWorkflow == WorkflowStatus.ProposalsRegistrationStarted,
            "Proposal registration session must be launched"
        );
        require(
            voters[msg.sender].isRegistered,
            "Voters must be registered"
        );

        proposals.push(Proposal({description: _proposalName, voteCount: 0}));
    }

    // Function terminating authorization to submit proposals (admin only)
    function stopProposalsRegistration() external onlyOwner {
        require(
            currentWorkflow == WorkflowStatus.ProposalsRegistrationStarted,
            "There are no current proposal registration assignments"
        );

        currentWorkflow = WorkflowStatus.ProposalsRegistrationEnded;

        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationStarted,
            WorkflowStatus.ProposalsRegistrationEnded
        );
    }

    // Function for opening votes (admin only)
    function startVotingSession() external onlyOwner {
        require(
            currentWorkflow == WorkflowStatus.ProposalsRegistrationEnded,
            "Proposals registration must be ended by the admin"
        );

        currentWorkflow = WorkflowStatus.VotingSessionStarted;

        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationEnded,
            WorkflowStatus.VotingSessionStarted
        );
    }

    // Voting function :
    // Recipient proposals will have their voteCount incremented by 1 each time.
    function vote(uint _proposalID) public {
        require(
            currentWorkflow == WorkflowStatus.VotingSessionStarted,
            "The vote session had to be started"
        );
        require(
            voters[msg.sender].isRegistered,
            "voters must be registered"
        );
        Voter storage sender = voters[msg.sender];
        require(!sender.hasVoted, "Already voted.");
        sender.hasVoted = true;
        sender.votedProposalId = _proposalID;

        proposals[_proposalID].voteCount += 1;
        emit Voted(msg.sender, _proposalID);
    }

    // Function ending the vote
    function stopVotingSession() external onlyOwner {
        require(
            currentWorkflow == WorkflowStatus.VotingSessionStarted,
            "Voting hasn't started"
        );

        currentWorkflow = WorkflowStatus.VotingSessionEnded;

        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionStarted,
            WorkflowStatus.VotingSessionEnded
        );
    }

    // Function that returns the id of the winning proposal (with the highest .voteCount attribute value first)
    function winningProposalId() public view returns (uint winningProposal_) {
        uint winningVoteCount = 0;
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                winningProposal_ = i;
            }
        }
    }

    // Function giving the name of the winning proposal
    function getWinnerName() public view returns (string memory winnerName_) {
        winnerName_ = proposals[winningProposalId()].description;
    }
}
