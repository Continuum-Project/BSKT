// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {DeployDAO} from "../../script/DeployDAO.s.sol";
import {Test} from "forge-std/Test.sol";

contract IntegrationDAO is Test {
    DeployDAO daoDeployer;
    address public dao;

    function setUp() public {
        daoDeployer = new DeployDAO();
        address[3] memory cmtHolders;
        (dao, cmtHolders) = daoDeployer.run();
        
    }

    function testDeployDAO() public {
        assertTrue(dao != address(0), "DAO not deployed");
    }
}