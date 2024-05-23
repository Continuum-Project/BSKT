// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "./TtcContextTest.sol";

contract TTCVaultTest is TtcTestContext {
    function testInitialLiquidity() public {
        setUp();
        // Check initial liquidity
        uint256 balanceWETH = ERC20(WETH_ADDRESS).balanceOf(address(vault));
        uint256 balanceWBTC = ERC20(WBTC_ADDRESS).balanceOf(address(vault));
        uint256 balanceSHIB = ERC20(SHIB_ADDRESS).balanceOf(address(vault));
        uint256 balanceTONCOIN = ERC20(TONCOIN_ADDRESS).balanceOf(address(vault));

        assertEq(balanceWETH, 0);
        assertEq(balanceWBTC, 0);
        assertEq(balanceSHIB, 0);
        assertEq(balanceTONCOIN, 0);

        address sender = makeAddr("sender");

        vm.startPrank(sender);
        initLiquidity(sender);
        vm.stopPrank();

        balanceWETH = ERC20(WETH_ADDRESS).balanceOf(address(vault));
        balanceWBTC = ERC20(WBTC_ADDRESS).balanceOf(address(vault));
        balanceSHIB = ERC20(SHIB_ADDRESS).balanceOf(address(vault));
        balanceTONCOIN = ERC20(TONCOIN_ADDRESS).balanceOf(address(vault));

        assertEq(balanceWETH, 166.6 ether);
        assertEq(balanceWBTC, 5 ether);
        assertEq(balanceSHIB, 3333333333.3 ether);
        assertEq(balanceTONCOIN, 14285.7 ether);
    }

    function testExclusiveFirstMint() public {
        setUp();

        address sender = makeAddr("sender");

        vm.startPrank(sender);

        vm.expectRevert();
        vault.allJoin_Out(100);

        TokenIO[] memory tokens = getDefaultTokens();

        vm.expectRevert();
        vault.allJoin_Min(tokens);

        vm.expectRevert();
        vault.singleJoin_AmountIn(Constituent(WETH_ADDRESS, 50), 100);

        vm.expectRevert();
        vault.singleJoin_AmountOut(Constituent(WETH_ADDRESS, 50), 100);
    }

    function testAllJoin_Out() public {
        address sender = liquidSetUp();

        uint denominator = 4; // NOTE: precision errors for odd numbers

        uint256 addedWETH = InitWETH / denominator;
        uint256 addedWBTC = InitWBTC / denominator;
        uint256 addedSHIB = InitSHIB / denominator;
        uint256 addedTONCOIN = InitTONCOIN / denominator;
        uint256 addedTTC = InitTTC / denominator;

        vm.startPrank(sender);
        dealAndApprove(WETH_ADDRESS, sender, addedWETH);
        dealAndApprove(WBTC_ADDRESS, sender, addedWBTC);
        dealAndApprove(SHIB_ADDRESS, sender, addedSHIB);
        dealAndApprove(TONCOIN_ADDRESS, sender, addedTONCOIN);

        vault.allJoin_Out(1 * PRECISION / denominator); // hence, the sender has to provide the same amounts of tokens currently in the vault divided by 2
        vm.stopPrank();

        assertEq(ERC20(WETH_ADDRESS).balanceOf(sender), 0);
        assertEq(ERC20(WBTC_ADDRESS).balanceOf(sender), 0);
        assertEq(ERC20(SHIB_ADDRESS).balanceOf(sender), 0);
        assertEq(ERC20(TONCOIN_ADDRESS).balanceOf(sender), 0);

        assertEq(ERC20(WETH_ADDRESS).balanceOf(address(vault)), InitWETH + addedWETH);
        assertEq(ERC20(WBTC_ADDRESS).balanceOf(address(vault)), InitWBTC + addedWBTC);
        assertEq(ERC20(SHIB_ADDRESS).balanceOf(address(vault)), InitSHIB + addedSHIB);
        assertEq(ERC20(TONCOIN_ADDRESS).balanceOf(address(vault)), InitTONCOIN + addedTONCOIN);

        // got half of TTC
        assertEq(ERC20(vault).balanceOf(sender), InitTTC + addedTTC);
    }

    function testAllJoin_Min() public {
        address sender = liquidSetUp();

        TokenIO[] memory tokens = getDefaultTokens();

        // increase amounts of tokens io, so min should take TONCOIN's proportion
        tokens[0].amount *= 2;
        tokens[1].amount *= 2;
        tokens[2].amount *= 2;

        vm.startPrank(sender);
        dealAndApprove(WETH_ADDRESS, sender, tokens[0].amount);
        dealAndApprove(WBTC_ADDRESS, sender, tokens[1].amount);
        dealAndApprove(SHIB_ADDRESS, sender, tokens[2].amount);
        dealAndApprove(TONCOIN_ADDRESS, sender, tokens[3].amount);

        vault.allJoin_Min(tokens);
        vm.stopPrank();

        // assert that TONCOIN's proportion was added
        assertEq(ERC20(WETH_ADDRESS).balanceOf(sender), tokens[0].amount / 2);
        assertEq(ERC20(WBTC_ADDRESS).balanceOf(sender), tokens[1].amount / 2);
        assertEq(ERC20(SHIB_ADDRESS).balanceOf(sender), tokens[2].amount / 2);
        assertEq(ERC20(TONCOIN_ADDRESS).balanceOf(sender), 0);

        assertEq(ERC20(WETH_ADDRESS).balanceOf(address(vault)), InitWETH + tokens[0].amount / 2);
        assertEq(ERC20(WBTC_ADDRESS).balanceOf(address(vault)), InitWBTC + tokens[1].amount / 2);
        assertEq(ERC20(SHIB_ADDRESS).balanceOf(address(vault)), InitSHIB + tokens[2].amount / 2);
        assertEq(ERC20(TONCOIN_ADDRESS).balanceOf(address(vault)), InitTONCOIN + tokens[3].amount);

        // got full TTC in return
        assertEq(ERC20(vault).balanceOf(sender), InitTTC * 2);
    }

    function testAllJoin_FailAssertion() public {
        address sender = liquidSetUp();

        // insufficient funds
        vm.startPrank(sender);
        vm.expectRevert();
        vault.allJoin_Min(getDefaultTokens());
        vm.stopPrank();

        // too high out amount requested
        vm.startPrank(sender);
        dealAndApprove(WETH_ADDRESS, sender, 1 * PRECISION);
        dealAndApprove(WBTC_ADDRESS, sender, 1 * PRECISION);
        dealAndApprove(SHIB_ADDRESS, sender, 1 * PRECISION);
        dealAndApprove(TONCOIN_ADDRESS, sender, 1 * PRECISION);

        vm.expectRevert();
        vault.allJoin_Out(1 * PRECISION);
        vm.stopPrank();

        // zero tokens in min
        vm.startPrank(sender);
        vm.expectRevert();
        vault.allJoin_Min(new TokenIO[](4));
        vm.stopPrank();
    }

    function testAllExit() public {
        address sender = liquidSetUp();

        // exit half of TTC
        uint256 _in = InitTTC / 2;

        vm.startPrank(sender);
        vault.allExit(_in);
        vm.stopPrank();

        // assert that half of TTC was burned
        assertEq(ERC20(vault).balanceOf(sender), InitTTC / 2);
        assertEq(ERC20(vault).totalSupply(), InitTTC / 2);

        // assert that half of the tokens were returned (with base fee)
        uint256 expectedETHBalance = chargeBaseFee(InitWETH / 2);
        uint256 expectedBTCBalance = chargeBaseFee(InitWBTC / 2);
        uint256 expectedSHIBBalance = chargeBaseFee(InitSHIB / 2);
        uint256 expectedTONCOINBalance = chargeBaseFee(InitTONCOIN / 2);

        assertEq(ERC20(WETH_ADDRESS).balanceOf(sender), expectedETHBalance);
        assertEq(ERC20(WBTC_ADDRESS).balanceOf(sender), expectedBTCBalance);
        assertEq(ERC20(SHIB_ADDRESS).balanceOf(sender), expectedSHIBBalance);
        assertEq(ERC20(TONCOIN_ADDRESS).balanceOf(sender), expectedTONCOINBalance);

        assertEq(ERC20(WETH_ADDRESS).balanceOf(address(vault)), InitWETH - expectedETHBalance);
        assertEq(ERC20(WBTC_ADDRESS).balanceOf(address(vault)), InitWBTC - expectedBTCBalance);
        assertEq(ERC20(SHIB_ADDRESS).balanceOf(address(vault)), InitSHIB - expectedSHIBBalance);
        assertEq(ERC20(TONCOIN_ADDRESS).balanceOf(address(vault)), InitTONCOIN - expectedTONCOINBalance);

        // exit remaining TTC
        vm.startPrank(sender);
        vault.allExit(InitTTC / 2);
        vm.stopPrank();

        // assert that all TTC was burned
        assertEq(ERC20(vault).balanceOf(sender), 0);
        assertEq(ERC20(vault).totalSupply(), 0);

        // assert that all the tokens were returned (with base fee)
        uint256 ethBalanceExit1 = InitWETH - expectedETHBalance;
        uint256 btcBalanceExit1 = InitWBTC - expectedBTCBalance;
        uint256 shibBalanceExit1 = InitSHIB - expectedSHIBBalance;
        uint256 toncoinBalanceExit1 = InitTONCOIN - expectedTONCOINBalance;

        expectedETHBalance += chargeBaseFee(ethBalanceExit1);
        expectedBTCBalance += chargeBaseFee(btcBalanceExit1);
        expectedSHIBBalance += chargeBaseFee(shibBalanceExit1);
        expectedTONCOINBalance += chargeBaseFee(toncoinBalanceExit1);

        assertEq(ERC20(WETH_ADDRESS).balanceOf(sender), expectedETHBalance);
        assertEq(ERC20(WBTC_ADDRESS).balanceOf(sender), expectedBTCBalance);
        assertEq(ERC20(SHIB_ADDRESS).balanceOf(sender), expectedSHIBBalance);
        assertEq(ERC20(TONCOIN_ADDRESS).balanceOf(sender), expectedTONCOINBalance);

        // only fee remains in the vault
        assertEq(ERC20(WETH_ADDRESS).balanceOf(address(vault)), InitWETH - expectedETHBalance);
        assertEq(ERC20(WBTC_ADDRESS).balanceOf(address(vault)), InitWBTC - expectedBTCBalance);
        assertEq(ERC20(SHIB_ADDRESS).balanceOf(address(vault)), InitSHIB - expectedSHIBBalance);
        assertEq(ERC20(TONCOIN_ADDRESS).balanceOf(address(vault)), InitTONCOIN - expectedTONCOINBalance);

        // exit zero TTC
        vm.startPrank(sender);
        vm.expectRevert();
        vault.allExit(0);
        vm.stopPrank();
    }

    function testSingleTokenJoin_AmountIn() public {
        address sender = liquidSetUp();

        // adding 1 WETH
        uint256 addedWETH = 1 * PRECISION;

        vm.startPrank(sender);
        dealAndApprove(WETH_ADDRESS, sender, addedWETH);

        vault.singleJoin_AmountIn(Constituent(WETH_ADDRESS, 50), addedWETH);
        vm.stopPrank();

        // assert correct TTC amount was minted
        // the added proportion `q` is: 299671034374982
        // the total supply of TTC is 1 * 10 ** 18 = 1000000000000000000
        // the new total supply of TTC is 1000000000000000000 * 2996710343749820 / ONE = 1002996710343749820
        // the new balance of the sender is 1000299671034374982
        // Source: https://www.wolframalpha.com/input?i=NumberForm%5B%28%5B%28166.6+%2B+1%29+%2F+%28166.6%29%5D+**+%281%2F2%29+-+1%29+*+10+**+18%2C+18%5D+
        uint256 expectedTTC = InitTTC + 2996710343749820;
        assertApproxEqAbs(ERC20(vault).balanceOf(sender), expectedTTC, DEFAULT_APPROXIMATION_ERROR);

        // assert correct amount of WETH was added
        assertEq(ERC20(WETH_ADDRESS).balanceOf(sender), 0);
        assertEq(ERC20(WETH_ADDRESS).balanceOf(address(vault)), InitWETH + addedWETH);

        // adding 1 WBTC
        uint256 addedWBTC = 1 * PRECISION;

        vm.startPrank(sender);
        dealAndApprove(WBTC_ADDRESS, sender, addedWBTC);

        vault.singleJoin_AmountIn(Constituent(WBTC_ADDRESS, 30), addedWBTC);
        vm.stopPrank();

        // assert correct TTC amount was minted
        // the added proportion `q` is: 5621996843925814
        // the total supply of TTC is 1002996710343749820
        // q * supply = 0.05638844340020535 * 10 ** 18 = 56388443400205350 // https://www.wolframalpha.com/input?i=NumberForm%5B%28%5B%285+%2B+1%29+%2F+%285%29%5D+**+%280.3%29+-+1%29+*+1.002996710343749820%2C+19%5D+
        expectedTTC += 56388443400205350;
        assertApproxEqAbs(ERC20(vault).balanceOf(sender), expectedTTC, DEFAULT_APPROXIMATION_ERROR);
    }
}