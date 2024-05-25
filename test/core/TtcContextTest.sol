// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/core/TTCVault.sol";
import "../../src/types/Vault.sol";

contract TtcTestContext is Test {
    TTCVault public vault;

    uint256 mainnetFork;

    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant SHIB_ADDRESS = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
    address constant TONCOIN_ADDRESS = 0x582d872A1B094FC48F5DE31D3B73F2D9bE47def1;

    uint256 constant PRECISION = 10**18;
    uint256 constant DEFAULT_APPROXIMATION_ERROR = 10**7; // 1/1000000000

    // Together, these assets are worth 1mil dollars
    // Prices assumed for tokens:
    // WETH: $3000
    // WBTC: $60000
    // SHIB: $0.00003
    // TONCOIN: $7
    uint256 constant InitWETH = 166.6 * 10 ** 18;
    uint256 constant InitWBTC = 5 * 10 ** 18;
    uint256 constant InitSHIB = 3333333333.3 * 10 ** 18;
    uint256 constant InitTONCOIN = 14285.7 * 10 ** 18;

    uint256 constant InitTTC = 1 * PRECISION;

    function setUp() public {
        Constituent[] memory initialConstituents = new Constituent[](4);
        initialConstituents[0] = Constituent(WETH_ADDRESS, 50);
        initialConstituents[1] = Constituent(WBTC_ADDRESS, 30);
        initialConstituents[2] = Constituent(SHIB_ADDRESS, 10);
        initialConstituents[3] = Constituent(TONCOIN_ADDRESS, 10);

        try vm.createFork(vm.envString("ALCHEMY_MAINNET_RPC_URL")) returns (uint256 forkId) {
            mainnetFork = forkId;
        } catch {
            mainnetFork = vm.createFork(vm.envString("INFURA_MAINNET_RPC_URL"));
        }
        vm.selectFork(mainnetFork);

        InitialETHDataFeeds[] memory initialDataFeeds = new InitialETHDataFeeds[](4);
        initialDataFeeds[0] = InitialETHDataFeeds(WBTC_ADDRESS, 0xdeb288F737066589598e9214E782fa5A8eD689e8);
        initialDataFeeds[1] = InitialETHDataFeeds(SHIB_ADDRESS, 0x8dD1CD88F43aF196ae478e91b9F5E4Ac69A97C61);
        // no data feed for TONCOIN

        vault = new TTCVault(initialConstituents, initialDataFeeds, WETH_ADDRESS);
    }

    // initializes the vault with the initial liquidity of $1mil dollars equivalent
    // Prices assumed for tokens:
    // WETH: $3000
    // WBTC: $60000
    // SHIB: $0.00003
    // TONCOIN: $7
    //
    // Amounts:
    // WETH: 166.666666666666666666
    // WBTC: 5
    // SHIB: 3,333,333,333.3333333333
    // TONCOIN: 14,285.7142857143
    function initLiquidity(address sender) public {
        TokenIO[] memory tokens = getDefaultTokens();

        // Approve the vault to spend the tokens
        dealAndApprove(WETH_ADDRESS, sender, InitWETH);
        dealAndApprove(WBTC_ADDRESS, sender, InitWBTC);
        dealAndApprove(SHIB_ADDRESS, sender, InitSHIB);
        dealAndApprove(TONCOIN_ADDRESS, sender, InitTONCOIN);

        vault.allJoin_Initial(tokens);
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
        ERC20(token).approve(address(vault), amount);
        deal(token, sender, amount);
    }

    function liquidSetUp() public returns (address) {
        setUp();
        address sender = makeAddr("sender");
        vm.startPrank(sender);
        initLiquidity(sender);
        vm.stopPrank();
        return sender;
    }
}