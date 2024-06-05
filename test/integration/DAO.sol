// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {DeployDAO} from "../../script/DeployDAO.s.sol";
import {Test} from "forge-std/Test.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {TTCVault} from "../../src/core/TTCVault.sol";
import {ContinuumDAO} from "../../src/dao/CDAO.sol";
import {console} from "forge-std/Test.sol";
import {BountyContract} from "../../src/dao/CBounty.sol";
import {CMT} from "../../src/dao/CMT.sol";
import {TTC} from "../../src/core/TTC.sol";
import {Constituent} from "../../src/types/CVault.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {console} from "forge-std/Test.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Integration is Test {
    ContinuumDAO public dao;
    TTCVault public ttcVault;
    BountyContract public bounty;
    CMT public cmt;
    TTC public ttc;

    address[3] defaultCmtHolders;

    string constant TTC_VAULT_CONTRACT_NAME = "TTCVault";
    string constant BOUNTY_CONTRACT_NAME = "BountyContract";
    string constant CMT_CONTRACT_NAME = "CMT";
    string constant TTC_CONTRACT_NAME = "TTC";

    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant SHIB_ADDRESS = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
    address constant TONCOIN_ADDRESS = 0x582d872A1B094FC48F5DE31D3B73F2D9bE47def1;

    uint256 public timelockDelay;

    function setUp() external {
        DeployDAO daoDeployer = new DeployDAO();
        daoDeployer.setupVault(msg.sender);
        daoDeployer.run(msg.sender);

        // fetch deployments
        bounty = daoDeployer.bounty();
        ttcVault = daoDeployer.vault();
        ttc = daoDeployer.ttc();
        cmt = daoDeployer.cmt();
        dao = daoDeployer.dao();
        
        for (uint256 i = 0; i < 3; i++) {
            defaultCmtHolders[i] = daoDeployer.defaultCmtHolders(i);
        }

        timelockDelay = daoDeployer.TIMELOCK_DELAY();
    }

    function testDeployDAO() public view {
        assertTrue(address(dao) != address(0), "DAO not deployed");
    }

    function testDeployTTCVault() public view {
        assertTrue(address(ttcVault) != address(0), "TTCVault not deployed");
    }

    function testBountyContractDeployed() public view {
        assertTrue(address(bounty) != address(0), "BountyContract not deployed");
    }

    function testTTCContractDeployed() public view {
        assertTrue(address(ttc) != address(0), "TTC not deployed");
    }

    function testCMTContractDeployed() public view {
        assertTrue(address(cmt) != address(0), "CMT not deployed");
    }

    function testOwnerships() public view {
        // Owned by DAO
        address ttcVaultOwner = ttcVault.owner();
        assertTrue(ttcVaultOwner == address(dao), "TTCVault not owned by DAO");

        address cmtOwner = cmt.owner();
        assertTrue(cmtOwner == address(dao), "CMT not owned by DAO");

        // Owned by TTCVault
        address ttcOwner = ttc.owner();
        assertTrue(ttcOwner == address(ttcVault), "TTC not owned by DAO");

        address bountyOwner = bounty.owner();
        assertTrue(bountyOwner == address(ttcVault), "BountyContract not owned by DAO");
    }
    
    // asserts that random addresses cannot interact with core contracts
    function testNonOwners_TTCVault() public {
        address randomSender = makeAddr("RANDOM_SENDER");

        // TTCVault
        vm.startPrank(randomSender);

        vm.expectRevert();
        ttcVault.createBounty(0, address(0), address(0));

        vm.expectRevert();
        ttcVault.fulfillBounty(0, 0);

        vm.expectRevert();
        ttcVault.transferOwnership(address(0));

        Constituent[] memory newConstituents = getInitialConstituents();

        vm.expectRevert();
        ttcVault.modifyConstituents(newConstituents);

        vm.stopPrank();
    }

    function testNonOwners_Bounty() public {
        address randomSender = makeAddr("RANDOM_SENDER");

        // Bounty
        vm.startPrank(randomSender);

        vm.expectRevert();
        bounty.createBounty(address(0), address(0), 0);

        vm.expectRevert();
        bounty.fulfillBounty(0, 0);

        vm.expectRevert();
        bounty.transferOwnership(address(0));

        vm.stopPrank();
    }

    function testNonOwners_CMT() public {
        address randomSender = makeAddr("RANDOM_SENDER");

        // CMT
        vm.startPrank(randomSender);

        vm.expectRevert();
        cmt.mint(address(0), 0);

        vm.expectRevert();
        cmt.burn(address(0), 0);

        vm.expectRevert();
        cmt.transferOwnership(address(0));

        vm.stopPrank();
    }

    function testNonOwners_TTC() public {
        address randomSender = makeAddr("RANDOM_SENDER");

        // TTC
        vm.startPrank(randomSender);

        vm.expectRevert();
        ttc.mint(address(0), 0);

        vm.expectRevert();
        ttc.burn(address(0), 0);

        vm.expectRevert();
        ttc.transferOwnership(address(0));

        vm.stopPrank();
    }

    function testDAO_createProposal() public {
        vm.roll(block.number + 1); // move one block

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(dao);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setProposalThreshold(uint256)", 50);

        vm.startPrank(defaultCmtHolders[0]);

        ERC20(cmt).approve(address(dao), dao.proposalFee());
        dao.propose(targets, values, calldatas, "Change Quorum Percentage to 50%");

        vm.stopPrank();

        uint256 proposalID = dao.hashProposal(targets, values, calldatas, keccak256("Change Quorum Percentage to 50%"));

        IGovernor.ProposalState proposalState = dao.state(proposalID);
        assertTrue(proposalState == IGovernor.ProposalState.Pending, "Proposal not pending");

        vm.roll(block.number + dao.votingDelay()); // move one block before voting period begins

        assertTrue(proposalState == IGovernor.ProposalState.Pending, "Proposal activated too early");

        vm.roll(block.number + 1); // move one block into voting period

        proposalState = dao.state(proposalID);
        assertTrue(proposalState == IGovernor.ProposalState.Active, "Proposal not activated");

        uint8 forVote = uint8(GovernorCountingSimple.VoteType.For);
        dao.castVote(proposalID, forVote);

        vm.roll(block.number + 1); // track small vote

        proposalState = dao.state(proposalID);
        assertTrue(proposalState == IGovernor.ProposalState.Active, "Proposal not activated");

        vm.stopPrank();
        vm.startPrank(address(dao)); // big vote (bring to 25% quorum)

        forVote = uint8(GovernorCountingSimple.VoteType.For);
        dao.castVote(proposalID, forVote);

        vm.roll(block.number + dao.votingPeriod() + 1); // finish voting period

        proposalState = dao.state(proposalID);
        assertTrue(proposalState == IGovernor.ProposalState.Succeeded, "Proposal not successfull");

        // queue proposal for execution
        dao.queue(targets, values, calldatas, keccak256("Change Quorum Percentage to 50%"));

        proposalState = dao.state(proposalID);
        assertTrue(proposalState == IGovernor.ProposalState.Queued, "Proposal not queued");

        vm.warp(block.timestamp + timelockDelay + 1); // finish voting period

        // execute proposal after timelock delay has passed
        dao.execute(targets, values, calldatas, keccak256("Change Quorum Percentage to 50%"));
        
        assertTrue(dao.proposalThreshold() == 50, "Quorum not changed");
    }

    // ------------ HELPERS ------------

    function getInitialConstituents() internal pure returns (Constituent[] memory){
        Constituent[] memory initialConstituents = new Constituent[](4);
        initialConstituents[0] = Constituent(WETH_ADDRESS, 50);
        initialConstituents[1] = Constituent(WBTC_ADDRESS, 30);
        initialConstituents[2] = Constituent(SHIB_ADDRESS, 10);
        initialConstituents[3] = Constituent(TONCOIN_ADDRESS, 10);

        return initialConstituents;
    }
}