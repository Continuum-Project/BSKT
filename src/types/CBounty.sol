// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

struct Bounty {
    uint256 bountyId;
    address creator;
    address tokenWant; // the token we want to get
    address tokenGive; // the token we want to give
    uint256 amountGive; // the amount of token we are giving out
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
