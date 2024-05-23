// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "./TTCConstants.sol";

contract TTCMath is TTCConstants {
    function toi(uint a)
        internal pure 
        returns (uint)
    {
        return a / ONE;
    }

    function floor(uint a)
        internal pure
        returns (uint)
    {
        return toi(a) * ONE;
    }

    function add(uint a, uint b)
        internal pure
        returns (uint)
    {
        uint c = a + b;
        require(c >= a, "ERR_ADD_OVERFLOW");
        return c;
    }

    function sub(uint a, uint b)
        internal pure
        returns (uint)
    {
        (uint c, bool flag) = subSign(a, b);
        require(!flag, "ERR_SUB_UNDERFLOW");
        return c;
    }

    function subSign(uint a, uint b)
        internal pure
        returns (uint, bool)
    {
        if (a >= b) {
            return (a - b, false);
        } else {
            return (b - a, true);
        }
    }

    function mul(uint a, uint b)
        internal pure
        returns (uint)
    {
        uint c0 = a * b;
        require(a == 0 || c0 / a == b, "ERR_MUL_OVERFLOW");
        uint c1 = c0 + (ONE / 2);
        require(c1 >= c0, "ERR_MUL_OVERFLOW");
        uint c2 = c1 / ONE;
        return c2;
    }

    function div(uint a, uint b)
        internal pure
        returns (uint)
    {
        require(b != 0, "ERR_DIV_ZERO");
        uint c0 = a * ONE;
        require(a == 0 || c0 / a == ONE, "ERR_DIV_INTERNAL"); // mul overflow
        uint c1 = c0 + (b / 2);
        require(c1 >= c0, "ERR_DIV_INTERNAL"); //  add require
        uint c2 = c1 / b;
        return c2;
    }

    // DSMath.wpow
    function powi(uint a, uint n)
        internal pure
        returns (uint)
    {
        uint z = n % 2 != 0 ? a : ONE;

        for (n /= 2; n != 0; n /= 2) {
            a = mul(a, a);

            if (n % 2 != 0) {
                z = mul(z, a);
            }
        }
        return z;
    }

    // Compute b^(e.w) by splitting it into (b^e)*(b^0.w).
    // Use `powi` for `b^e` and `powK` for k iterations
    // of approximation of b^0.w
    function pow(uint base, uint exp)
        internal pure
        returns (uint)
    {
        require(base >= MIN_POW_BASE, "ERR_pow_BASE_TOO_LOW");
        require(base <= MAX_POW_BASE, "ERR_pow_BASE_TOO_HIGH");

        uint whole  = floor(exp);   
        uint remain = sub(exp, whole);

        uint wholePow = powi(base, toi(whole));

        if (remain == 0) {
            return wholePow;
        }

        uint partialResult = powApprox(base, remain, POW_PRECISION);
        return mul(wholePow, partialResult);
    }

    function powApprox(uint base, uint exp, uint precision)
        internal pure
        returns (uint)
    {
        // term 0:
        uint a     = exp;
        (uint x, bool xneg)  = subSign(base, ONE);
        uint term = ONE;
        uint sum   = term;
        bool negative = false;


        // term(k) = numer / denom 
        //         = (product(a - i - 1, i=1-->k) * x^k) / (k!)
        // each iteration, multiply previous term by (a-(k-1)) * x / k
        // continue until term is less than precision
        for (uint i = 1; term >= precision; i++) {
            uint bigK = i * ONE;
            (uint c, bool cneg) = subSign(a, sub(bigK, ONE));
            term = mul(term, mul(c, x));
            term = div(term, bigK);
            if (term == 0) break;

            if (xneg) negative = !negative;
            if (cneg) negative = !negative;
            if (negative) {
                sum = sub(sum, term);
            } else {
                sum = add(sum, term);
            }
        }

        return sum;
    }

}
