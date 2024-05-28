// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "./DeployTTCVault.s.sol";
import "../src/dao/CMT.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ContinuumDAO} from "../src/dao/CDAO.sol";

import {console} from "forge-std/Test.sol";

contract DeployDAO is Script{
    // returns:
    // address of DAO
    // array of addresses of holders of CMT tokens
    function run() public returns(address, address[3] memory){
        DeployTTCVault ttcVaultScript = new DeployTTCVault();
        (TTCVault vault, BountyContract bounty) = ttcVaultScript.run();

        address holder1 = makeAddr("CMT_HOLDER_1");
        address holder2 = makeAddr("CMT_HOLDER_2");
        address holder3 = makeAddr("CMT_HOLDER_3");

        vm.startBroadcast();
        CMT cmt = new CMT();
        mintCMT(cmt, holder1, 1000); // create 3000 CMT tokens
        mintCMT(cmt, holder2, 1000);
        mintCMT(cmt, holder3, 1000);

        TimelockController timelock = new TimelockController(7200, new address[](0), new address[](0), msg.sender);
        ContinuumDAO dao = new ContinuumDAO(cmt, timelock);
        mintCMT(cmt, address(dao), 10000); // create 10000 CMT tokens for the DAO

        vault.transferOwnership(address(dao)); // transfer ownership of the vault to the DAO
        bounty.transferOwnership(address(dao)); // transfer ownership of the bounty to the DAO
        cmt.transferOwnership(address(dao)); // transfer ownership of the CMT to the DAO

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(dao));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(dao));
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(dao));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender); // renounce admin role

        assertions(dao, timelock, vault);
        vm.stopBroadcast();

        return (address(dao), [holder1, holder2, holder3]);
    }

    function mintCMT(CMT cmt, address holder, uint256 amount) public {
        cmt.mint(holder, amount);
    }

    function assertions(ContinuumDAO dao, TimelockController timeLock, TTCVault vault) public {
        // make sure the DAO has the correct roles
        assert(timeLock.hasRole(timeLock.PROPOSER_ROLE(), address(dao)));
        assert(timeLock.hasRole(timeLock.EXECUTOR_ROLE(), address(dao)));
        assert(timeLock.hasRole(timeLock.DEFAULT_ADMIN_ROLE(), address(dao)));
        assert(!timeLock.hasRole(timeLock.DEFAULT_ADMIN_ROLE(), msg.sender));

        // make sure sender cannot access vault's methods that are onlyOwner
        // vm.expectRevert();
        // vault.testOwnership();
    }
}