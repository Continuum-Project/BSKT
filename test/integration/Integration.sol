// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {DeployDAO} from "../../script/DeployDAO.s.sol";
import {Test} from "forge-std/Test.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {TTCVault} from "../../src/core/TTCVault.sol";
import {ContinuumDAO} from "../../src/dao/CDAO.sol";
import {BountyContract, Bounty, BountyStatus} from "../../src/dao/CBounty.sol";
import {CMT} from "../../src/dao/CMT.sol";
import {TTC} from "../../src/core/TTC.sol";
import {Constituent, TokenIO} from "../../src/types/CVault.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
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
    address constant LINK_ADDRESS = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    uint256 constant InitWETH = 166.6 * 10 ** 18;
    uint256 constant InitWBTC = 5 * 10 ** 18;
    uint256 constant InitSHIB = 3333333333.3 * 10 ** 18;
    uint256 constant InitTONCOIN = 14285.7 * 10 ** 18;

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

        uint256 proposerBalanceBeforeProposal = ERC20(cmt).balanceOf(defaultCmtHolders[0]);
        ERC20(cmt).approve(address(dao), dao.proposalFee());
        dao.propose(targets, values, calldatas, "Change Quorum Percentage to 50%");
        assertTrue(
            ERC20(cmt).balanceOf(defaultCmtHolders[0]) == proposerBalanceBeforeProposal - dao.proposalFee(),
            "Proposal fee not deducted"
        );

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

        // assert that proposal fee is returned
        assertTrue(
            ERC20(cmt).balanceOf(defaultCmtHolders[0]) == proposerBalanceBeforeProposal, "Proposal fee not returned"
        );
        assertTrue(dao.proposalThreshold() == 50, "Quorum not changed");
    }

    function testDAO_modifyConstituentsViaProposal_NoReconstitution() public {
        vm.roll(block.number + 1); // move one block

        initLiquidity(makeAddr("sender"));

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        // First, create a bounty
        targets[0] = address(dao);
        values[0] = 0;
        uint256 onePercentBtc = InitWBTC / ttcVault.getTokenWeight(WBTC_ADDRESS);
        calldatas[0] = abi.encodeWithSignature(
            "createBounty(address,uint8,address,uint8,uint256)",
            SHIB_ADDRESS,
            ttcVault.getTokenWeight(SHIB_ADDRESS) + 1,
            WBTC_ADDRESS,
            ttcVault.getTokenWeight(WBTC_ADDRESS) - 1,
            onePercentBtc // swapping 1% of BTC for SHIB
        );

        proposeAndExecute(targets, values, calldatas);

        // check that bounty was created
        Bounty memory b = bounty.getBounty(0);
        assertTrue(b.amountGive == onePercentBtc, "Bounty not created");

        // Second, fulfill this bounty
        address fulfiller = makeAddr("fulfiller");

        vm.startPrank(fulfiller, fulfiller);
        // TODO: make this dynamic
        uint256 hardcodedSHIBToBTC = 2307692307 * (onePercentBtc + 1) * 10 ** ERC20(SHIB_ADDRESS).decimals(); // ~2307692307 per one btc, +1 to make sure oracle will pass the amount
        dealAndApprove(SHIB_ADDRESS, fulfiller, hardcodedSHIBToBTC);

        ERC20(SHIB_ADDRESS).approve(address(bounty), hardcodedSHIBToBTC);
        dao.fulfillBounty(0, hardcodedSHIBToBTC);

        vm.stopPrank();

        b = bounty.getBounty(0);
        assertTrue(b.status == BountyStatus.FULFILLED, "Bounty not fulfilled");

        assertTrue(ttcVault.getTokenWeight(WBTC_ADDRESS) == 29, "WBTC weight not changed");
        assertTrue(ttcVault.getTokenWeight(SHIB_ADDRESS) == 11, "SHIB weight not changed");
    }

    // Tests two things: reconstitution proposal and datafeed proposal
    function testDAO_modifyConstituentsViaProposal_Reconstitution() public {
        vm.roll(block.number + 1); // move one block

        initLiquidity(makeAddr("sender"));

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        // First, create a datafeed proposal addition to add LINK datafeed
        address lINKDataFeed = address(0xDC530D9457755926550b59e8ECcdaE7624181557);

        targets[0] = address(dao);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("addPriceFeed(address,address)", LINK_ADDRESS, lINKDataFeed);

        proposeAndExecute(targets, values, calldatas);

        // First, create a bounty
        targets[0] = address(dao);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "createBounty(address,uint8,address,uint8,uint256)",
            LINK_ADDRESS,
            ttcVault.getTokenWeight(SHIB_ADDRESS), // same weight as SHIB
            SHIB_ADDRESS,
            0, // SHIB will be 0
            InitSHIB // swapping all SHIB for LINK
        );

        proposeAndExecute(targets, values, calldatas);

        // fulfill bounty
        address fulfiller = makeAddr("fulfiller");

        vm.startPrank(fulfiller, fulfiller);

        uint256 hardcodedLINKForSHIB = 6190 * 10 ** ERC20(LINK_ADDRESS).decimals(); // 6190 LINK for InitSHIB TODO: make this dynamic

        dealAndApprove(LINK_ADDRESS, fulfiller, hardcodedLINKForSHIB);
        ERC20(LINK_ADDRESS).approve(address(bounty), hardcodedLINKForSHIB);

        dao.fulfillBounty(0, hardcodedLINKForSHIB);

        vm.stopPrank();

        Bounty memory b = bounty.getBounty(0);

        assertTrue(b.status == BountyStatus.FULFILLED, "Bounty not fulfilled");
        assertTrue(ttcVault.getTokenWeight(SHIB_ADDRESS) == 0, "SHIB weight not changed");
        assertTrue(ttcVault.getTokenWeight(LINK_ADDRESS) == 10, "LINK not added");
        assertTrue(ERC20(LINK_ADDRESS).balanceOf(address(ttcVault)) == hardcodedLINKForSHIB, "LINK not added");
        assertTrue(ERC20(SHIB_ADDRESS).balanceOf(address(ttcVault)) == 0, "SHIB not removed");
    }

    function testSanity() public {
        address user = makeAddr("user");
        initLiquidity(user); // make sure that normal users can mint

        // check that users can't acces sensitive methods of:
        // TTC
        // TTCVault
        // BountyContract
        // CMT
        // ContinuumDAO

        vm.startPrank(user);

        // TTC
        vm.expectRevert();
        ttc.mint(user, 100);

        vm.expectRevert();
        ttc.burn(user, 100);

        vm.expectRevert();
        ttc.transferOwnership(user);

        // TTCVault
        vm.expectRevert();
        ttcVault.createBounty(0, address(0), address(0));

        vm.expectRevert();
        ttcVault.fulfillBounty(0, 0);

        vm.expectRevert();
        ttcVault.transferOwnership(address(0));

        Constituent[] memory newConstituents = getInitialConstituents();

        vm.expectRevert();
        ttcVault.modifyConstituents(newConstituents);

        vm.expectRevert();
        ttcVault.collectYield(WETH_ADDRESS);

        // Bounty
        vm.expectRevert();
        bounty.createBounty(address(0), address(0), 0);

        vm.expectRevert();
        bounty.fulfillBounty(0, 0);

        vm.expectRevert();
        bounty.transferOwnership(address(0));

        // CMT
        vm.expectRevert();
        cmt.mint(address(0), 0);

        vm.expectRevert();
        cmt.burn(address(0), 0);

        vm.expectRevert();
        cmt.transferOwnership(address(0));

        // ContinuumDAO
        vm.expectRevert();
        dao.addPriceFeed(address(0), address(0));

        vm.expectRevert();
        dao.createBounty(address(0), 0, address(0), 0, 0);

        vm.expectRevert();
        dao.fulfillBounty(0, 0); // asserts that user without funds cannot do that

        vm.expectRevert();
        dao.setProposalThreshold(0);
    }

    // ------------ HELPERS ------------

    function getInitialConstituents() internal pure returns (Constituent[] memory) {
        Constituent[] memory initialConstituents = new Constituent[](4);
        initialConstituents[0] = Constituent(WETH_ADDRESS, 50);
        initialConstituents[1] = Constituent(WBTC_ADDRESS, 30);
        initialConstituents[2] = Constituent(SHIB_ADDRESS, 10);
        initialConstituents[3] = Constituent(TONCOIN_ADDRESS, 10);

        return initialConstituents;
    }

    function getDefaultTokens() public pure returns (TokenIO[] memory) {
        TokenIO[] memory tokens = new TokenIO[](4);
        tokens[0] = TokenIO(WETH_ADDRESS, InitWETH);
        tokens[1] = TokenIO(WBTC_ADDRESS, InitWBTC);
        tokens[2] = TokenIO(SHIB_ADDRESS, InitSHIB);
        tokens[3] = TokenIO(TONCOIN_ADDRESS, InitTONCOIN);

        return tokens;
    }

    function dealAndApprove(address token, address sender, uint256 amount) public {
        deal(token, sender, amount);
        ERC20(token).approve(address(ttcVault), amount);
    }

    function initLiquidity(address sender) public {
        vm.startPrank(sender);
        TokenIO[] memory tokens = getDefaultTokens();

        // Approve the vault to spend the tokens
        dealAndApprove(WETH_ADDRESS, sender, InitWETH);
        dealAndApprove(WBTC_ADDRESS, sender, InitWBTC);
        dealAndApprove(SHIB_ADDRESS, sender, InitSHIB);
        dealAndApprove(TONCOIN_ADDRESS, sender, InitTONCOIN);

        ttcVault.allJoin_Initial(tokens);
        vm.stopPrank();
    }

    function proposeAndExecute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas) public {
        vm.startPrank(defaultCmtHolders[0]);

        ERC20(cmt).approve(address(dao), dao.proposalFee());
        dao.propose(targets, values, calldatas, "DEFAULT");

        vm.stopPrank();

        vm.roll(block.number + dao.votingDelay() + 1); // start voting period

        uint256 proposalID = dao.hashProposal(targets, values, calldatas, keccak256("DEFAULT"));

        vm.startPrank(address(dao)); // big voter votes

        uint8 forVote = uint8(GovernorCountingSimple.VoteType.For);
        dao.castVote(proposalID, forVote);

        vm.stopPrank();

        vm.roll(block.number + dao.votingPeriod() + 1); // finish voting period

        dao.queue(targets, values, calldatas, keccak256("DEFAULT"));

        vm.warp(block.timestamp + timelockDelay + 1); // finish timelock delay

        dao.execute(targets, values, calldatas, keccak256("DEFAULT"));

        vm.stopPrank();
    }
}
