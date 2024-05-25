// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../types/CBounty.sol";

interface IBountyContract {
    event BOUNTY_CREATED (
        address indexed sender, 
        uint256 indexed bountyId,
        uint256 indexed amount
    );

    event BOUNTY_FULFILLED (
        address indexed fulfiller, 
        uint256 indexed bountyId
    );

    function createBounty(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountOut
    ) external returns (uint256);

    function fulfillBounty(uint256 _bountyId, uint256 amountIn) external;

    function getBounty(uint256 _bountyId) external view returns (Bounty memory);
}

// Mock contract for better code readability in the Bounty contract
contract WETHDataFeed is AggregatorV3Interface {
    ERC20 public weth;

    constructor(address _weth) {
        weth = ERC20(_weth);
    }
    function decimals() external view override returns (uint8) {
        return weth.decimals();
    }

    function description() external pure override returns (string memory) {
        return "WETH/ETH";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId) external pure override returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        return (_roundId, 1, 0, 0, 0);
    }

    function latestRoundData() external pure override returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        return (0, 10**18, 0, 0, 0);
    }
}