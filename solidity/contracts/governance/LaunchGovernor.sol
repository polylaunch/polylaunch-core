// SPDX-License-Identifier: MIT

pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../system/PolylaunchConstants.sol";
import "../../interfaces/BasicLaunchInterface.sol";

contract GovernorAlpha {
    /// @notice The name of this contract
    string public name;

    // Flag stating whether the contract has been initialised or not
    bool private initialised;

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint256) {
        return PolylaunchConstants.getVotingDelay();
    } // time

    /// @notice The delay before a proposal may be executed after it has been queued
    function executionDelay() public pure returns (uint256) {
        return PolylaunchConstants.getExecutionDelay();
    } // 2 days

    /// @notice The duration of voting on a proposal, in time
    function votingPeriod() public pure returns (uint256) {
        return PolylaunchConstants.getVotingPeriod();
    } // ~7 days in blocks (assuming 15s blocks)

    /// @notice The duration after which a proposal expires after it has been queued
    function gracePeriod() public pure returns (uint256) {
        return PolylaunchConstants.getGracePeriod();
    } // 14 days

    /// @notice The address of the launch being governed
    BasicLaunchInterface public basicLaunch;

    /// @notice The address of the launch token
    GovernableERC20Interface public launchToken;

    /// @notice The address of the venture bond
    VentureBondInterface public ventureBond;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    /// @notice Currently queued proposals
    mapping(uint256 => bool) public queuedProposals;

    struct Proposal {
        // Unique id for looking up a proposal
        uint256 id;
        // Creator of the proposal
        address proposer;
        // The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        // The new tap rate being proposed
        uint256 newRate;
        // the ordered list of target addresses for calls to be made
        uint256 startTime;
        // start block is before the start time, since its just used for recordkeeping
        uint256 startBlock;
        // The block at which voting ends: votes must be cast prior to this block
        uint256 endTime;
        // Current number of votes in favor of this proposal
        uint256 forVotes;
        // Current number of votes in opposition to this proposal
        uint256 againstVotes;
        // Flag marking whether the proposal has been canceled
        bool canceled;
        // Flag marking whether the proposal has been executed
        bool executed;
        // Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
        // Venture bonds already used to vote on proposal
        mapping(uint256 => bool) ventureBondsUsed;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        // Address of the voter that cast the vote
        address voter;
        // Whether or not a vote has been cast
        bool hasVoted;
        // Whether or not the voter supports the proposal
        bool support;
        // The number of votes the voter had, which were cast
        uint96 votes;
        // The venture bond used to vote
        uint256 ventureBondId;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice The official record of all proposals
    mapping(uint256 => Proposal) public proposals;

    /// @notice The id of the latest tap increase proposal
    uint256 public latestTapIncreaseProposalId;

    /// @notice The id of the latest refund proposal
    uint256 public latestRefundProposalId;

    /// @notice An event emitted when a new tap increase proposal is created
    event TapIncreaseProposalCreated(
        uint256 id,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        string description,
        uint256 newRate
    );

    /// @notice An event emitted when a new refund proposal is created
    event RefundProposalCreated(
        uint256 id,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        string description
    );

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(
        address voter,
        uint256 ventureBondId,
        uint256 proposalId,
        bool support,
        uint256 votes
    );

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    modifier onlyTokenOwner(uint256 tokenId) {
        require(
            ventureBond.ownerOf(tokenId) == msg.sender,
            "LaunchGovernor::onlyTokenOwner: Sender does not own a venture bond with the given id"
        );
        _;
    }

    modifier holdsVentureBond() {
        uint256 numberOfTokensOwned = ventureBond.balanceOf(msg.sender);
        require(
            numberOfTokensOwned >= 1,
            "LaunchGovernor::holdsVentureBond: Sender does not own a venture bond"
        );
        _;
    }

    modifier isBondAssociatedWithLaunch(uint256 tokenId){
        require(
            ventureBond.launchAddressAssociatedWithToken(tokenId) == address(basicLaunch),
            "isBondAssociatedWithLaunch: Token not associated with this launch"
        );
        _;
    }

    function init(
        string memory name_,
        address basicLaunch_,
        address launchToken_,
        address ventureBond_
    ) public {
        require(!initialised, "Contract already initialised");
        initialised = true;

        name = name_;
        basicLaunch = BasicLaunchInterface(basicLaunch_);
        launchToken = GovernableERC20Interface(launchToken_);
        ventureBond = VentureBondInterface(ventureBond_);
    }

    function proposeTapIncrease(uint256 newRate, string memory description)
        public
        returns (uint256)
    {
        require(
            msg.sender == basicLaunch.launcher(),
            "LaunchGovernor::proposeTapIncrease: only the launcher can propose a tap increase"
        );
        require(
            newRate > basicLaunch.launcherTapRate(),
            "LaunchGovernor::proposeTapIncrease: new tap rate must be greater than current tap rate"
        );

        if (latestTapIncreaseProposalId != 0) {
            ProposalState latestProposalState =
                state(latestTapIncreaseProposalId);
            require(
                latestProposalState != ProposalState.Active,
                "LaunchGovernor::proposeTapIncrease: found an already active tap increase proposal"
            );
            require(
                latestProposalState != ProposalState.Pending,
                "LaunchGovernor::proposeTapIncrease: found an already pending tap increase proposal"
            );
        }

        uint256 startTime = add256(block.timestamp, votingDelay());
        uint256 endTime = add256(startTime, votingPeriod());

        proposalCount++;
        Proposal storage p = proposals[proposalCount];

        p.id = proposalCount;
        p.proposer = msg.sender;
        p.eta = 0;
        p.newRate = newRate;
        p.startTime = startTime;
        p.endTime = endTime;
        p.forVotes = 0;
        p.againstVotes = 0;
        p.canceled = false;
        p.executed = false;

        latestTapIncreaseProposalId = p.id;

        emit TapIncreaseProposalCreated(
            p.id,
            msg.sender,
            startTime,
            endTime,
            description,
            newRate
        );
        return p.id;
    }

    function proposeRefund(string memory description, uint256 tokenId) public returns (uint256) {
        require(
            (ventureBond.ownerOf(tokenId) == msg.sender && ventureBond.launchAddressAssociatedWithToken(tokenId) == address(basicLaunch)) ||
                msg.sender == basicLaunch.launcher(),
            "LaunchGovernor::proposeRefund: Must be launcher or hold a venture bond to propose a refund"
        );
        if (latestRefundProposalId != 0) {
            ProposalState latestProposalState = state(latestRefundProposalId);
            require(
                latestProposalState != ProposalState.Active,
                "LaunchGovernor::proposeRefundVote: found an already active refund proposal"
            );
            require(
                latestProposalState != ProposalState.Pending,
                "LaunchGovernor::proposeRefundVote: found an already pending refund proposal"
            );
        }

        uint256 startTime = add256(block.timestamp, votingDelay());
        uint256 endTime = add256(startTime, votingPeriod());

        proposalCount++;
        Proposal storage p = proposals[proposalCount];

        p.id = proposalCount;
        p.proposer = msg.sender;
        p.eta = 0;
        p.newRate = 0;
        p.startTime = startTime;
        p.endTime = endTime;
        p.forVotes = 0;
        p.againstVotes = 0;
        p.canceled = false;
        p.executed = false;

        latestRefundProposalId = p.id;

        emit RefundProposalCreated(
            p.id,
            msg.sender,
            startTime,
            endTime,
            description
        );
        return p.id;
    }

    function queue(uint256 proposalId) public {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "LaunchGovernor::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.eta = add256(block.timestamp, executionDelay());

        require(
            !queuedProposals[proposalId],
            "LaunchGovernor::queue: proposal action already queued"
        );

        queuedProposals[proposalId] = true;

        emit ProposalQueued(proposalId, proposal.eta);
    }

    function execute(uint256 proposalId) public payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "LaunchGovernor::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = proposals[proposalId];
        require(
            block.timestamp >= proposal.eta,
            "LaunchGovernor::execute: Transaction hasn't surpassed time lock"
        );
        require(
            block.timestamp <= add256(proposal.eta, gracePeriod()),
            "LaunchGovernor::execute: Transaction is stale"
        );

        if (proposal.newRate != 0) {
            require(
                msg.sender == proposal.proposer,
                "LaunchGovernor::execute: Tap increase proposals can only be executed by the proposer"
            );
            basicLaunch.increaseTap(proposal.newRate);
        } else {
            basicLaunch.initiateRefundMode();
        }

        proposal.executed = true;
        queuedProposals[proposalId] = false;
        emit ProposalExecuted(proposalId);
    }

    function getReceipt(uint256 proposalId, address voter)
        public
        view
        returns (Receipt memory)
    {
        return proposals[proposalId].receipts[voter];
    }

    function quorumReached(Proposal storage proposal)
        internal
        view
        returns (bool)
    {
        uint256 absent =
            sub256(
                basicLaunch.totalVotingPower(),
                add256(proposal.forVotes, proposal.againstVotes)
            );
        return proposal.forVotes - proposal.againstVotes > (absent / 6);
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.id != 0,
            "LaunchGovernor::state: Proposal with given ID does not exist"
        );
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.timestamp <= proposal.startTime) {
            return ProposalState.Pending;
        } else if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        } else if (!quorumReached(proposal)) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= add256(proposal.eta, gracePeriod())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function castVote(
        uint256 ventureBondId,
        uint256 proposalId,
        bool support
    ) public onlyTokenOwner(ventureBondId) isBondAssociatedWithLaunch(ventureBondId) {
        return _castVote(msg.sender, ventureBondId, proposalId, support);
    }

    function _castVote(
        address voter,
        uint256 ventureBondId,
        uint256 proposalId,
        bool support
    ) internal {
        require(
            state(proposalId) == ProposalState.Active,
            "LaunchGovernor::_castVote: voting is closed"
        );
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        if (proposal.startBlock == 0){
            // start block is -1 of current so the first vote caster isnt reverted
            proposal.startBlock = block.number - 1;
        }
        require(
            receipt.hasVoted == false,
            "LaunchGovernor::_castVote: voter already voted"
        );
        require(
            proposal.ventureBondsUsed[ventureBondId] == false,
            "LaunchGovernor::_castVote: venture bond already used to vote in this proposal"
        );
        uint256 votes =
            min(
                ventureBond.votingPower(ventureBondId),
                launchToken.getPriorVotes(voter, proposal.startBlock) +
                    ventureBond.tappableBalance(ventureBondId)
            );

        if (support) {
            proposal.forVotes = add256(proposal.forVotes, votes);
        } else {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = uint96(votes);
        receipt.ventureBondId = ventureBondId;
        proposal.ventureBondsUsed[ventureBondId] = true;

        emit VoteCast(voter, ventureBondId, proposalId, support, votes);
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

interface GovernableERC20Interface {
    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        returns (uint96);
}

interface VentureBondInterface {
    function votingPower(uint256 tokenId) external view returns (uint256);

    function balanceOf(address owner) external returns (uint256);

    function ownerOf(uint256 tokenId) external returns (address);

    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        returns (uint256);

    function tappableBalance(uint256 tokenId) external view returns (uint256);

    function launchAddressAssociatedWithToken(uint256 tokenId) external view returns (address);
}
