// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "./DeployTTCVault.sol";
import "../src/dao/CMT.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ContinuumDAO} from "../src/dao/CDAO.sol";

import {console} from "forge-std/Test.sol";

contract DeployDAO is Script{
    function run() public {
        DeployTTCVault ttcVaultScript = new DeployTTCVault();
        (TTCVault vault, BountyContract bounty) = ttcVaultScript.run();

        vm.startBroadcast();
        CMT cmt = new CMT();
        TimelockController timelock = new TimelockController(7200, new address[](0), new address[](0), msg.sender);
        ContinuumDAO dao = new ContinuumDAO(cmt, timelock);

        vault.transferOwnership(address(dao)); // transfer ownership of the vault to the DAO
        bounty.transferOwnership(address(dao)); // transfer ownership of the bounty to the DAO
        cmt.transferOwnership(address(dao)); // transfer ownership of the CMT to the DAO

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(dao));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(dao));
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(dao));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender); // renounce admin role

        vm.stopBroadcast();
    }
}