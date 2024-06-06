// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IFeeCollectable {
    event FeeCollected(address receiver, uint256 feeCollected);

    function collectFee(uint256 _amount) external;
    function collectFee() external;
}