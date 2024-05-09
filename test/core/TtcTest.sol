// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../../src/core/TTC.sol";

contract TtcTest is Test{
    address public ttcOwner;
    TTC public ttcToken;

    function setUp() public {
        ttcOwner = makeAddr("TTC Owner");
        vm.prank(ttcOwner);
        ttcToken = new TTC();
    }

    function testTokenName() public view {
        assertEq(ttcToken.name(), "Top Ten Continuum");
    }

    function testTokenSymbol() public view {
        assertEq(ttcToken.symbol(), "TTC");
    }

    function testTokenDecimals() public view {
        assertEq(ttcToken.decimals(), 18);
    }

    function testTtcInitialSupply() public view {
        assertEq(ttcToken.totalSupply(), 0);
    }

    function testTtcOwner() public view {
        assertEq(ttcToken.owner(), ttcOwner);
    }

    function testMint(uint96 amountOfTokens) public {
        address user = makeAddr("user");
        uint amountToMint = amountOfTokens * (10 ** ttcToken.decimals());
        vm.startPrank(ttcOwner);
        ttcToken.mint(user, amountToMint);
        vm.stopPrank();
        assertEq(ttcToken.balanceOf(user), amountToMint);
        assertEq(ttcToken.totalSupply(), amountToMint);
    }

    function testInvalidMint(uint96 amountOfTokens) public {
        address user = makeAddr("user");
        address recipient = makeAddr("recipient");
        uint amountToMint = amountOfTokens * (10 ** ttcToken.decimals());
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vm.startPrank(user);
        ttcToken.mint(recipient, amountToMint);
        vm.stopPrank();
    }

    function testBurn(uint96 amountOfTokens) public {
        testMint(amountOfTokens);
        address user = makeAddr("user");
        uint amountToBurn = amountOfTokens * (10 ** ttcToken.decimals());
        vm.startPrank(ttcOwner);
        ttcToken.burn(user, amountToBurn);
        vm.stopPrank();
        assertEq(ttcToken.balanceOf(user), 0);
        assertEq(ttcToken.totalSupply(), 0);
    }

    function testInvalidBurn(uint96 amountOfTokens) public {
        testMint(amountOfTokens);
        address user = makeAddr("user");
        uint amountToBurn = amountOfTokens * (10 ** ttcToken.decimals());
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vm.startPrank(user);
        ttcToken.mint(user, amountToBurn);
        vm.stopPrank();
    }

}
