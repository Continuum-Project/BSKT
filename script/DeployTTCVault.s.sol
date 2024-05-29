// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TTCVault} from "../src/core/TTCVault.sol";
import {BountyContract} from "../src/dao/CBounty.sol";
import {console} from "forge-std/Test.sol";

import "../src/types/CBounty.sol";
import "../src/types/CVault.sol";

contract DeployTTCVault is Script {
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant SHIB_ADDRESS = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
    address constant TONCOIN_ADDRESS = 0x582d872A1B094FC48F5DE31D3B73F2D9bE47def1;

    function run() external returns(address, TTCVault, BountyContract) {
        Constituent[] memory initialConstituents = getInitialConstituents();
        InitialETHDataFeeds[] memory initialDataFeeds = getInitialDataFeeds();

        vm.startBroadcast(msg.sender);
        BountyContract bounty = new BountyContract(initialDataFeeds, WETH_ADDRESS);
        TTCVault ttcVault = new TTCVault(initialConstituents, address(bounty));
        vm.stopBroadcast();

        return (msg.sender, ttcVault, bounty);
    }

    function getInitialConstituents() internal pure returns (Constituent[] memory){
        Constituent[] memory initialConstituents = new Constituent[](4);
        initialConstituents[0] = Constituent(WETH_ADDRESS, 50);
        initialConstituents[1] = Constituent(WBTC_ADDRESS, 30);
        initialConstituents[2] = Constituent(SHIB_ADDRESS, 10);
        initialConstituents[3] = Constituent(TONCOIN_ADDRESS, 10);

        return initialConstituents;
    }

    function getInitialDataFeeds() internal view returns(InitialETHDataFeeds[] memory) {
        InitialETHDataFeeds[] memory initialDataFeeds = new InitialETHDataFeeds[](4);

        if (block.chainid == 1) { // mainnet data feeds
            initialDataFeeds[0] = InitialETHDataFeeds(WBTC_ADDRESS, 0xdeb288F737066589598e9214E782fa5A8eD689e8);
            initialDataFeeds[1] = InitialETHDataFeeds(SHIB_ADDRESS, 0x8dD1CD88F43aF196ae478e91b9F5E4Ac69A97C61);
            // no data feed for TONCOIN
        }

        return initialDataFeeds;
    }


    // function getNullTokens() public pure returns (TokenIO[] memory) {
    //     TokenIO[] memory tokens = new TokenIO[](4);
    //     tokens[0] = TokenIO(WETH_ADDRESS, 0);
    //     tokens[1] = TokenIO(WBTC_ADDRESS, 0);
    //     tokens[2] = TokenIO(SHIB_ADDRESS, 0);
    //     tokens[3] = TokenIO(TONCOIN_ADDRESS, 0);

    //     return tokens;
    // }
}