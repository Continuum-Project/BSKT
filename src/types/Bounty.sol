// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

struct Bounty {
    uint256 bountyId;
    address creator;
    address tokenIn; // the token we want to get rid of
    address tokenOut; // the token we actually want to add
    uint256 amountOut; // the amount of token we are giving out
    BountyStatus status;
}

struct InitialETHDataFeeds {
    address token;
    address dataFeed;
}

enum BountyStatus {
    ACTIVE,
    FULFILLED
}