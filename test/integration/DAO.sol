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

contract IntegrationDAO is Test {
    ContinuumDAO public dao;
    TTCVault public ttcVault;
    BountyContract public bounty;
    CMT public cmt;
    TTC public ttc;

    string constant TTC_VAULT_CONTRACT_NAME = "TTCVault";
    string constant BOUNTY_CONTRACT_NAME = "BountyContract";
    string constant CMT_CONTRACT_NAME = "CMT";
    string constant TTC_CONTRACT_NAME = "TTC";

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

    // function testTimelockContractDeployed() public {
    //     address timelockAddress = DevOpsTools.get_most_recent_deployment("TimelockController", block.chainid);
    //     assertTrue(timelockAddress != address(0), "TimelockController not deployed");
    // }

    function testOwnerships() public view {
        address ttcVaultOwner = ttcVault.owner();
        assertTrue(ttcVaultOwner == address(dao), "TTCVault not owned by DAO");

        address bountyOwner = bounty.owner();
        assertTrue(bountyOwner == address(ttcVault), "BountyContract not owned by DAO");

        address cmtOwner = cmt.owner();
        assertTrue(cmtOwner == address(dao), "CMT not owned by DAO");

        address ttcOwner = ttc.owner();
        assertTrue(ttcOwner == address(ttcVault), "TTC not owned by DAO");
    }
}