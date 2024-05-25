// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IBounty {
    event BOUNTY_CREATED (
        address indexed sender, 
        uint256 indexed bountyId,
        uint256 indexed amount
    );

    event BOUNTY_FULFILLED (
        address indexed fulfiller, 
        uint256 indexed bountyId
    );

    struct Bounty {
        uint256 bountyId;
        address creator;
        address tokenIn; // the token we want to get rid of
        address tokenOut; // the token we actually want to add
        uint256 amountOut; // the amount of token we are giving out
        BountyStatus status;
    }
    
    enum BountyStatus {
        ACTIVE,
        FULFILLED
    }

    function createBounty(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountOut
    ) external returns (uint256);

    function fulfillBounty(uint256 _bountyId) external;

    function getBounty(uint256 _bountyId) external view returns (Bounty memory);
}