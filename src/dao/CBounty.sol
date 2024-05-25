// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


import {IBountyContract, WETHDataFeed} from "../interface/IBounty.sol";
import {InitialETHDataFeeds, BountyStatus, Bounty} from "../types/CBounty.sol";

contract BountyContract is IBountyContract, Ownable {
    modifier _activeBounty_(uint256 _bountyId) {
        require(bounties[_bountyId].status == BountyStatus.ACTIVE, "Bounty not active");
        _;
    }

    modifier _hasDatafeed_(address _token) {
        require(address(dataFeed[_token]) != address(0), "Datafeed not found");
        _;
    }

    mapping(uint256 => Bounty) public bounties;
    mapping(address => AggregatorV3Interface) internal dataFeed;

    uint256 bountyCount;

    // Data Feed for WETH should NOT be provided in _dataFeeds
    constructor(InitialETHDataFeeds[] memory _dataFeeds, address wethAddress) Ownable(msg.sender) {
        for (uint256 i = 0; i < _dataFeeds.length; i++) {
            dataFeed[_dataFeeds[i].token] = AggregatorV3Interface(_dataFeeds[i].dataFeed);
        }

        dataFeed[wethAddress] = new WETHDataFeed(wethAddress);
        bountyCount = 0;
    }

    function createBounty(address _tokenWant, address _tokenGive, uint256 _amountGive)
        external 
        onlyOwner
        returns(uint256)
    {
        Bounty memory bounty = Bounty({
            bountyId: bountyCount,
            creator: msg.sender, // should be DAO
            tokenWant: _tokenWant,
            tokenGive: _tokenGive,
            amountGive: _amountGive,
            status: BountyStatus.ACTIVE
        });

        bounties[bountyCount] = bounty;
        bountyCount++;

        emit BOUNTY_CREATED(msg.sender, bounty.bountyId, _amountGive);

        return bounty.bountyId;
    }

    function fulfillBounty(uint256 _bountyId, uint256 amountIn) 
        external 
        _activeBounty_(_bountyId)
    {
        _fulfillBounty(bounties[_bountyId], amountIn);

        bounties[_bountyId].status = BountyStatus.FULFILLED;

        emit BOUNTY_FULFILLED(msg.sender, _bountyId);
    }

    function getBounty(uint256 _bountyId) 
        external 
        view 
        returns (Bounty memory)
    {
        return bounties[_bountyId];
    }

    function _fulfillBounty(Bounty memory bounty, uint256 amountIn) 
        internal
        _hasDatafeed_(bounty.tokenWant)
        _hasDatafeed_(bounty.tokenGive)
    {
        address fulfiller = msg.sender;
        address creator = bounty.creator;

        // find value of tokenWant 
        address tokenWant = bounty.tokenWant;
        uint256 tokenWantValue = _value(tokenWant, amountIn);

        // find value of tokenGive
        address tokenGive = bounty.tokenGive;
        uint256 tokenGiveValue = _value(tokenGive, bounty.amountGive);

        // check if the fulfiller has provided enough value
        require(tokenWantValue >= tokenGiveValue, "Value discrepancy too high");

        // transfer the tokens
        ERC20(tokenWant).transferFrom(fulfiller, creator, amountIn);
        ERC20(tokenGive).transferFrom(creator, fulfiller, bounty.amountGive);
    }

    function _value(address _token, uint256 _amount) 
        internal 
        view 
        _hasDatafeed_(_token)
        returns (uint256)
    {
        AggregatorV3Interface tokenFeed = dataFeed[_token];
        (, int256 tokenPrice, , , ) = tokenFeed.latestRoundData();
        return _amount * uint256(tokenPrice);
    }
}