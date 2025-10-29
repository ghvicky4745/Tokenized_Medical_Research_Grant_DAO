// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Tokenized Medical Research Grant DAO
 * @dev A decentralized autonomous organization for funding medical research projects
 */
contract Project {
    
    struct ResearchProposal {
        uint256 id;
        address researcher;
        string title;
        string description;
        uint256 fundingGoal;
        uint256 currentFunding;
        uint256 votesFor;
        uint256 votesAgainst;
        bool isActive;
        bool isFunded;
        mapping(address => bool) hasVoted;
    }
    
    struct Member {
        uint256 tokens;
        bool isMember;
        uint256 joinedAt;
    }
    
    mapping(uint256 => ResearchProposal) public proposals;
    mapping(address => Member) public members;
    
    uint256 public proposalCount;
    uint256 public totalSupply;
    uint256 public constant MEMBERSHIP_FEE = 0.1 ether;
    uint256 public constant TOKENS_PER_MEMBERSHIP = 100;
    
    address public admin;
    
    event MemberJoined(address indexed member, uint256 tokens);
    event ProposalCreated(uint256 indexed proposalId, address indexed researcher, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalFunded(uint256 indexed proposalId, uint256 amount);
    event FundsWithdrawn(uint256 indexed proposalId, address indexed researcher, uint256 amount);
    
    modifier onlyMember() {
        require(members[msg.sender].isMember, "Not a DAO member");
        _;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this");
        _;
    }
    
    constructor() {
        admin = msg.sender;
    }
    
    /**
     * @dev Join the DAO by paying membership fee and receiving governance tokens
     */
    function joinDAO() external payable {
        require(!members[msg.sender].isMember, "Already a member");
        require(msg.value == MEMBERSHIP_FEE, "Incorrect membership fee");
        
        members[msg.sender] = Member({
            tokens: TOKENS_PER_MEMBERSHIP,
            isMember: true,
            joinedAt: block.timestamp
        });
        
        totalSupply += TOKENS_PER_MEMBERSHIP;
        
        emit MemberJoined(msg.sender, TOKENS_PER_MEMBERSHIP);
    }
    
    /**
     * @dev Create a research proposal requesting funding
     * @param _title Title of the research project
     * @param _description Detailed description of the research
     * @param _fundingGoal Amount of funding requested in wei
     */
    function createProposal(
        string memory _title,
        string memory _description,
        uint256 _fundingGoal
    ) external onlyMember {
        require(_fundingGoal > 0, "Funding goal must be greater than 0");
        
        proposalCount++;
        ResearchProposal storage newProposal = proposals[proposalCount];
        
        newProposal.id = proposalCount;
        newProposal.researcher = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.fundingGoal = _fundingGoal;
        newProposal.isActive = true;
        newProposal.isFunded = false;
        
        emit ProposalCreated(proposalCount, msg.sender, _title);
    }
    
    /**
     * @dev Vote on a research proposal
     * @param _proposalId ID of the proposal to vote on
     * @param _support True to vote for, false to vote against
     */
    function voteOnProposal(uint256 _proposalId, bool _support) external onlyMember {
        ResearchProposal storage proposal = proposals[_proposalId];
        
        require(proposal.isActive, "Proposal is not active");
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");
        
        proposal.hasVoted[msg.sender] = true;
        uint256 votingPower = members[msg.sender].tokens;
        
        if (_support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }
        
        emit VoteCast(_proposalId, msg.sender, _support);
        
        // Auto-fund if votes exceed threshold (simple majority)
        if (proposal.votesFor > totalSupply / 2 && !proposal.isFunded) {
            _fundProposal(_proposalId);
        }
    }
    
    /**
     * @dev Internal function to fund an approved proposal
     * @param _proposalId ID of the proposal to fund
     */
    function _fundProposal(uint256 _proposalId) internal {
        ResearchProposal storage proposal = proposals[_proposalId];
        
        require(address(this).balance >= proposal.fundingGoal, "Insufficient DAO funds");
        
        proposal.isFunded = true;
        proposal.currentFunding = proposal.fundingGoal;
        proposal.isActive = false;
        
        emit ProposalFunded(_proposalId, proposal.fundingGoal);
    }
    
    /**
     * @dev Withdraw funds for a funded research proposal
     * @param _proposalId ID of the proposal
     */
    function withdrawFunds(uint256 _proposalId) external {
        ResearchProposal storage proposal = proposals[_proposalId];
        
        require(msg.sender == proposal.researcher, "Only researcher can withdraw");
        require(proposal.isFunded, "Proposal not funded");
        require(proposal.currentFunding > 0, "Funds already withdrawn");
        
        uint256 amount = proposal.currentFunding;
        proposal.currentFunding = 0;
        
        payable(proposal.researcher).transfer(amount);
        
        emit FundsWithdrawn(_proposalId, msg.sender, amount);
    }
    
    /**
     * @dev Donate to the DAO treasury
     */
    function donateToDAO() external payable {
        require(msg.value > 0, "Donation must be greater than 0");
    }
    
    /**
     * @dev Get proposal details
     * @param _proposalId ID of the proposal
     */
    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        address researcher,
        string memory title,
        string memory description,
        uint256 fundingGoal,
        uint256 currentFunding,
        uint256 votesFor,
        uint256 votesAgainst,
        bool isActive,
        bool isFunded
    ) {
        ResearchProposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.researcher,
            proposal.title,
            proposal.description,
            proposal.fundingGoal,
            proposal.currentFunding,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.isActive,
            proposal.isFunded
        );
    }
    
    /**
     * @dev Check if address has voted on a proposal
     */
    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }
    
    /**
     * @dev Get DAO contract balance
     */
    function getDAOBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
