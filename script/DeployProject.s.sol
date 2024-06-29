// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "./DeployDAO.s.sol";

contract DeployAll is Script {
    function run() public {
        // if invoked via forge script
        run(msg.sender);
    }

    function run(address owner) public {
        // if invoked via forge test
        DeployDAO dao = new DeployDAO();
        dao.setupVault(owner);
        dao.run(owner);
    }
}