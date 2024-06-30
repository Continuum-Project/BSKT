// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../types/CVault.sol";

interface ITTCVault {
    event ALL_JOIN(address indexed sender, uint256 iOut); // iOut: index out

    event ALL_EXIT(address indexed sender, uint256 iIn); // iIn: index in

    event SINGLE_JOIN(address indexed sender, address indexed token, uint256 iOut, uint256 amountIn);

    event SINGLE_EXIT(address indexed sender, address indexed token, uint256 iIn, uint256 amountOut);

    function allJoin_Out(uint256 out) external;

    function allJoin_Min(TokenIO[] calldata tokens) external;

    function allExit(uint256 _in) external;

    function singleJoin_AmountIn(Constituent calldata constituentIn, uint256 amountIn) external;

    function singleJoin_AmountOut(Constituent calldata constituentIn, uint256 out) external;

    // function singleExit(Constituent calldata constituentOut, uint256 _in) external;

    function modifyConstituents(Constituent[] calldata newConstituents) external;

    function createBounty(uint256 amountGive, address tokenGive, address tokenWant)
        external
        returns (uint256 bountyId);

    function fulfillBounty(uint256 _bountyId, uint256 amountIn) external;
}
