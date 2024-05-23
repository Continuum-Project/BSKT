// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../src/core/TTCVault.sol";
import "../../src/types/Types.sol";

contract TtcTestContext is Test {
    TTCVault public vault;

    uint256 mainnetFork;

    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant SHIB_ADDRESS = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
    address constant TONCOIN_ADDRESS = 0x582d872A1B094FC48F5DE31D3B73F2D9bE47def1;

    uint256 constant PRECISION = 10 ** 18;

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

        vault = new TTCVault(initialConstituents);
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
        ERC20(WETH_ADDRESS).approve(address(vault), 166.6 ether);
        ERC20(WBTC_ADDRESS).approve(address(vault), 5 ether);
        ERC20(SHIB_ADDRESS).approve(address(vault), 3333333333.3 ether);
        ERC20(TONCOIN_ADDRESS).approve(address(vault), 14285.7 ether);

        // deal
        deal(WETH_ADDRESS, sender, 166.6 ether);
        deal(WBTC_ADDRESS, sender, 5 ether);
        deal(SHIB_ADDRESS, sender, 3333333333.3 ether);
        deal(TONCOIN_ADDRESS, sender, 14285.7 ether);

        vault.allJoin_Initial(tokens);
    }

    function getDefaultTokens() public pure returns (TokenIO[] memory) {
        TokenIO[] memory tokens = new TokenIO[](4);
        tokens[0] = TokenIO(WETH_ADDRESS, 166.6 ether);
        tokens[1] = TokenIO(WBTC_ADDRESS, 5 ether);
        tokens[2] = TokenIO(SHIB_ADDRESS, 3333333333.3 ether);
        tokens[3] = TokenIO(TONCOIN_ADDRESS, 14285.7 ether);

        return tokens;
    }
}