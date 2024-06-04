// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "./DeployTTCVault.s.sol";
import "../src/dao/CMT.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ContinuumDAO} from "../src/dao/CDAO.sol";

import {console} from "forge-std/Test.sol";

contract DeployDAO is Script{
    modifier paramteresSet() {
        require(address(vault) != address(0), "Vault not set");
        require(address(bounty) != address(0), "Bounty not set");
        require(address(ttc) != address(0), "TTC not set");
        _;
    }

    ContinuumDAO public dao;
    CMT public cmt;

    TTCVault public vault;
    BountyContract public bounty;
    TTC public ttc;
    address[3] defaultCmtHolders;

    function setupVault(address _owner) public returns(address) {
        address vaultOwner;
        DeployTTCVault deployer = new DeployTTCVault();
        (vaultOwner, vault, bounty, ttc) = deployer.run(_owner);
        return vaultOwner;
    }

    function run() public paramteresSet { // if invoked via forge script
        run(msg.sender);
    }

    function run(address owner) public paramteresSet { // if invoked via forge test
        address holder1 = makeAddr("CMT_HOLDER_1");
        address holder2 = makeAddr("CMT_HOLDER_2");
        address holder3 = makeAddr("CMT_HOLDER_3");

        vm.startBroadcast(owner);
        CMT _cmt = new CMT();
        mintCMT(_cmt, holder1, 1000); // create 3000 CMT tokens
        mintCMT(_cmt, holder2, 1000);
        mintCMT(_cmt, holder3, 1000);

        TimelockController timelock = new TimelockController(7200, new address[](0), new address[](0), owner);
        ContinuumDAO _dao = new ContinuumDAO(_cmt, timelock);
        mintCMT(_cmt, address(_dao), 10000); // create 10000 CMT tokens for the DAO

        vault.transferOwnership(address(_dao)); // transfer ownership of the vault to the DAO
        bounty.transferOwnership(address(_dao)); // transfer ownership of the bounty to the DAO
        _cmt.transferOwnership(address(_dao)); // transfer ownership of the CMT to the DAO

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(_dao));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(_dao));
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(_dao));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), owner); // renounce admin role

        vm.stopBroadcast();

        defaultCmtHolders = [holder1, holder2, holder3];
        dao = _dao;
        cmt = _cmt;
    }

    function mintCMT(CMT _cmt, address holder, uint256 amount) public {
        _cmt.mint(holder, amount);
    }
}