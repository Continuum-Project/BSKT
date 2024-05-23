// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../../src/core/TTC.sol";

contract TtcTest is Test, TTC {
    address public ttcOwner;

    function setUp() public {
        ttcOwner = makeAddr("TTC Owner");
        vm.prank(ttcOwner);
    }

    function testTokenName() public view {
        assertEq(name(), "Top Ten Continuum");
    }

    function testTokenSymbol() public view {
        assertEq(symbol(), "TTC");
    }

    function testTokenDecimals() public view {
        assertEq(decimals(), 18);
    }

    function testTtcInitialSupply() public view {
        assertEq(totalSupply(), 0);
    }

    function testTtcOwner() public view {
        assertEq(owner(), ttcOwner);
    }

    function testMint(uint96 amountOfTokens) public {
        address user = makeAddr("user");
        uint amountToMint = amountOfTokens * (10 ** decimals());
        vm.startPrank(ttcOwner);
        mint(user, amountToMint);
        vm.stopPrank();
        assertEq(balanceOf(user), amountToMint);
        assertEq(totalSupply(), amountToMint);
    }

    function testInvalidMint(uint96 amountOfTokens) public {
        address user = makeAddr("user");
        address recipient = makeAddr("recipient");
        uint amountToMint = amountOfTokens * (10 ** decimals());
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vm.startPrank(user);
        mint(recipient, amountToMint);
        vm.stopPrank();
    }

    function testBurn(uint96 amountOfTokens) public {
        testMint(amountOfTokens);
        address user = makeAddr("user");
        uint amountToBurn = amountOfTokens * (10 ** decimals());
        vm.startPrank(ttcOwner);
        burn(user, amountToBurn);
        vm.stopPrank();
        assertEq(balanceOf(user), 0);
        assertEq(totalSupply(), 0);
    }

    function testInvalidBurn(uint96 amountOfTokens) public {
        testMint(amountOfTokens);
        address user = makeAddr("user");
        uint amountToBurn = amountOfTokens * (10 ** decimals());
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vm.startPrank(user);
        mint(user, amountToBurn);
        vm.stopPrank();
    }

}
