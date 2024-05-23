// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

struct Constituent {
    address token;
    uint8 norm;
}

// Token (In/Out)
struct TokenIO {
    address token;
    uint256 amount;
}