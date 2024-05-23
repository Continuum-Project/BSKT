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
}