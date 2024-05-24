// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

contract TTCConstants {
    string public constant TTC_NAME = "Top Ten Continuum";
    string public constant TTC_SYMBOL = "TTC";
    uint256 public constant ONE = 10 ** 18;

    uint public constant MIN_POW_BASE     = 1 wei;
    uint public constant MAX_POW_BASE     = (2 * ONE) - 1 wei;
    uint public constant POW_PRECISION    = ONE / 10**12;
}