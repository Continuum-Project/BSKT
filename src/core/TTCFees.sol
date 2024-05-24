// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "./TTCConstants.sol";

contract TTCFees is TTCConstants {
    event FeeCharged(
        address indexed sender,
        uint256 fee
    );

    uint256 constant public BASE_REDEMPTION_FEE = 5 * ONE / 10000; // 0.05%

    // The fee charged during a single token join in addition to base fee times (1 - W_i) * 100
    // Fee charged for token with normalized weight of 0.2 is 0.05% + (1 - 0.2) * 0.001% * 100 = 0.05% + 0.08% = 0.13%
    uint256 constant public FEE_MARGIN = 10 * ONE / 1000000; // 0.001%

    /**
     * @notice Charge a base fee of 0.05% for an amount
     * @param amount The amount of tokens to charge the fee on
     * @return The amount of tokens after the fee has been charged
     */
    function chargeBaseFee(uint256 amount) internal returns (uint256) {
        uint256 fee = amount * BASE_REDEMPTION_FEE / ONE;
        emit FeeCharged(msg.sender, fee);
        return amount - fee;
    }

    /**
     * @notice Charge a fee for a token join
     * @param amount The amount of tokens to charge the fee on
     * @param norm The normalized weight of the token
     * @return The amount of tokens after the fee has been charged
     */
    function chargeBaseFeePlusMarginal(uint256 amount, uint8 norm) internal returns (uint256) {
        uint256 _norm = norm * ONE / 100;
        uint256 normReciprocal = ONE - _norm;
        uint256 feep = BASE_REDEMPTION_FEE + normReciprocal * FEE_MARGIN * 100 / ONE; // fee percentage
        uint256 fee = amount * feep / ONE;
        emit FeeCharged(msg.sender, fee);
        return amount - fee;
    }

    /**
     * @notice Split an amount into two parts, one balanced and one not balanced
     * @param amount The amount to split
     * @param norm The normalized weight of the token
     * @return norm*amount/100, (100-norm)*amount/100
     */
    function splitBalancedNotBalanced(uint256 amount, uint8 norm) internal pure returns (uint256, uint256) {
        uint256 _norm = norm * ONE / 100;
        uint256 amountBalanced = amount * _norm / ONE;

        return (amountBalanced, amount - amountBalanced);
    }
}