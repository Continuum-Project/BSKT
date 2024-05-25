// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


import {IBounty} from "../interface/IBounty.sol";

contract Bounty is IBounty, Ownable {
    AggregatorV3Interface internal dataFeed;

    modifier _activeBounty_(uint256 _bountyId) {
        require(bounties[_bountyId].status == BountyStatus.ACTIVE, "Bounty not active");
        _;
    }

    mapping(uint256 => Bounty) public bounties;

    uint256 bountyCount;

    constructor() Ownable(msg.sender) {
        bountyCount = 0;
    }

    function createBounty(address _tokenIn,address _tokenOut, uint256 _amountOut)
        external 
        onlyOwner 
        returns(uint256)
    {
        Bounty memory bounty = Bounty({
            bountyId: bountyCount,
            creator: msg.sender,
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            amountOut: _amountOut,
            status: BountyStatus.ACTIVE
        });

        bounties[bountyCount] = bounty;
        bountyCount++;

        emit BOUNTY_CREATED(msg.sender, bounty.bountyId, _amountOut);

        return bounty.bountyId;
    }

    function fulfillBounty(uint256 _bountyId) 
        external 
        onlyOwner
        _activeBounty_(_bountyId)
    {
        bounties[_bountyId].status = BountyStatus.FULFILLED;

        emit BOUNTY_FULFILLED(msg.sender, _bountyId);
    }

    function _fulfillBounty(Bounty memory bounty) 
        internal
    {
        address fulfiller = msg.sender;
        address tokenIn = bounty.tokenIn;

        // transfer tokenIn from owner to fulfiller
        ERC20(tokenIn).transferFrom(bounty.creator, fulfiller, bounty.amountOut);

    }
}