// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {Bounty} from "./CBounty.sol";
import {CMT} from "./CMT.sol";
import {TTCVault} from "../core/TTCVault.sol";

contract ContinuumDAO is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    CMT public immutable cmt;
    TTCVault public immutable ttcVault;

    uint256 proposalFee = 100; // 100 CMT
    string constant NAME = "Continuum DAO";
    uint8 constant QUORUM_PERCENTAGE = 25;

    mapping(uint256 => address) public proposalToCreator;
    
    constructor(
        CMT _cmt,
        TTCVault _ttcVault,
        TimelockController _timelock
    ) Governor(NAME) GovernorVotes(_cmt) GovernorVotesQuorumFraction(QUORUM_PERCENTAGE) GovernorTimelockControl(_timelock) {
        cmt = _cmt;
        ttcVault = _ttcVault;
    }

    // ----------- CUSTOM -----------
    function fulfillBounty(uint256 _bountyId, uint256 amountIn) public {
        ttcVault.fulfillBounty(_bountyId, amountIn);
    }

    // ----------- OVERRIDES -----------

    function votingDelay() public pure override returns (uint256) {
        return 7200; // 1 day
    }

    function votingPeriod() public pure override returns (uint256) {
        return 50400 * 4; // 4 weeks
    }

    function proposalThreshold() public pure override returns (uint256) {
        return 0;
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