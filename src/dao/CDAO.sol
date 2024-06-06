// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {Bounty} from "./CBounty.sol";
import {CMT} from "./CMT.sol";
import {TTCVault} from "../core/TTCVault.sol";
import {Constituent} from "../types/CVault.sol";
import {console} from "forge-std/Test.sol";

contract ContinuumDAO is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    GovernorSettings
{
    string constant NAME = "Continuum DAO";

    uint48 constant VOTING_DELAY = 1 days;
    uint32 constant VOTING_PERIOD = 4 weeks;
    uint256 constant PROPOSAL_THRESHOLD = 0;
    uint8 public constant QUORUM_PERCENT = 25;

    CMT public immutable cmt;
    TTCVault public immutable ttcVault;

    uint256 public proposalFee = 100; // 100 CMT

    struct SwapConstituentsRecord {
        address tokenIn;
        uint8 weightIn;
        address tokenOut;
        uint8 weightOut;
    }

    mapping(uint256 => address) private proposalToCreator;
    mapping(uint256 => SwapConstituentsRecord) private proposalToConstituents;
    
    constructor(
        CMT _cmt,
        TTCVault _ttcVault,
        TimelockController _timelock
    ) Governor(NAME) GovernorVotes(_cmt) GovernorVotesQuorumFraction(QUORUM_PERCENT) GovernorTimelockControl(_timelock) GovernorSettings(VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD){
        cmt = _cmt;
        ttcVault = _ttcVault;
    }

    // ----------- CUSTOM -----------

    function fulfillBounty(uint256 _bountyId, uint256 amountIn) public {
        ttcVault.fulfillBounty(_bountyId, amountIn);

        SwapConstituentsRecord memory swapConstituents = proposalToConstituents[_bountyId];
        uint256 cLength = ttcVault.constituentsLength();
        Constituent[] memory newConstituents = new Constituent[](cLength);

        for (uint256 i = 0; i < cLength; i++) {
            (address cAddress, uint8 cWeight) = ttcVault.s_constituents(i);
            Constituent memory c = Constituent(cAddress, cWeight);
            if (cAddress != swapConstituents.tokenOut && cAddress != swapConstituents.tokenIn) { // not changing tokens, skip
                newConstituents[i] = c;
                continue; 
            }

            // if cAddress is tokenIn, match the weight
            if (cAddress == swapConstituents.tokenIn) {
                c.norm = swapConstituents.weightIn;
                newConstituents[i] = c;
                continue;
            }

            // if cAddress is tokenOut, adjust the current constituent
            if (cAddress == swapConstituents.tokenOut) {
                if (swapConstituents.weightOut == 0) { // if token out is removed, replace it with token in
                    c.norm = swapConstituents.weightIn;
                    c.token = swapConstituents.tokenIn;
                    newConstituents[i] = c;
                    continue;
                } else { // if token remains in vault, adjust the weight
                    c.norm = swapConstituents.weightOut;
                    newConstituents[i] = c;
                    continue;
                }
            }
        }

        ttcVault.modifyConstituents(newConstituents);
    }

    function createBounty(
        address _tokenIn,
        uint8 _tokenInWeight,
        address _tokenOut,
        uint8 _tokenOutWeight,
        uint256 _amountOut
    ) public onlyGovernance returns (uint256) {
        uint256 bountyID =  ttcVault.createBounty(_amountOut, _tokenOut, _tokenIn);

        proposalToConstituents[bountyID] = SwapConstituentsRecord(_tokenIn, _tokenInWeight, _tokenOut, _tokenOutWeight);

        return bountyID;
    }

    // ----------- OVERRIDES -----------

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor) returns(uint256) {
        // charge proposal fee
        cmt.transferFrom(msg.sender, address(this), proposalFee);

        // propose 
        uint256 proposalId = super.propose(targets, values, calldatas, description);

        // log creator
        proposalToCreator[proposalId] = msg.sender;

        return proposalId;
    }

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override(Governor) returns(uint256) {
        // return proposal fee on successful execution
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
        address creator = proposalToCreator[proposalId];
        cmt.transfer(creator, proposalFee);

        return super.execute(targets, values, calldatas, descriptionHash);
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view virtual override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}