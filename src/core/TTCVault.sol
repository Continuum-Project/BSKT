// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./TTC.sol";
import "../types/Types.sol";
import "./TTCMath.sol";
import "../interface/ITTCVault.sol";

contract TTCVault is ITTCVault, TTC, TTCMath {
    modifier _lock_() {
        require(!_locked, "ERR_REENTRANCY");
        _locked = true;
        _;
        _locked = false;
    }

    modifier _validTokensIn_(TokenIO[] calldata _tokens) {
        require(_checkTokensIn(_tokens), "ERR_INVALID_TOKENS");
        _;
    }

    modifier _isLocked_() {
        require(_locked, "ERR_NOT_LOCKED");
        _;
    }

    modifier _positiveIn_(uint256 _in) {
        require(_in > 0, "ERR_ZERO_IN");
        _;
    }

    modifier _notFirstJoin_() {
        require(totalSupply() > 0, "ERR_FIRST_JOIN");
        _;
    }

    uint256 constant BASE_REDEMPTION_FEE = 5 * ONE / 10000; // 0.05%

    bool private _locked;
    Constituent[] public constituents;

    constructor(Constituent[] memory initialConstituents) {
        for (uint256 i = 0; i < initialConstituents.length; i++) {
            constituents.push(initialConstituents[i]);
        }
    }

    function allJoin_Initial(TokenIO[] calldata tokens)
        external
        _lock_
    {
        require(totalSupply() == 0, "ERR_NOT_FIRST_JOIN");
        _allJoin(tokens, 1); // mint 1 TTC, sets the initial price
    }

    /*
     * @notice all-tokens join, providing the desired amount of TTC out
     * @notice It is responsibility of a caller to check that they have the correct amount of tokens
     * @param _tokens The tokens to deposit
     * @param _amounts The amounts of tokens to deposit
     */
    function allJoin_Out(uint256 out) 
        external 
        _lock_
        _notFirstJoin_
    {
        uint propIn = mul(out, totalSupply()); // the proportion of each token to deposit in order to get "out" amount
        TokenIO[] memory tokensIn = new TokenIO[](constituents.length);
        for (uint256 i = 0; i < constituents.length; i++) {
            uint256 balance = IERC20(constituents[i].token).balanceOf(address(this));
            tokensIn[i].amount = mul(balance, propIn);
            tokensIn[i].token = constituents[i].token;
        }

        _allJoin(tokensIn, out);
    }

    /*
     * @notice all-tokens join, providing the list of tokens a sender is willing to deposit, the contract searches for the best all-tokens join
     * @param _tokens The tokens to deposit
     * @param _amounts The amounts of tokens to deposit
     */
    function allJoin_Min(TokenIO[] calldata tokens) 
        external 
        _lock_
        _validTokensIn_(tokens)
        _notFirstJoin_
    {
        uint256 minProp = type(uint256).max;
        for (uint256 i = 0; i < constituents.length; i++) {
            uint256 prop = div(tokens[i].amount, ERC20(constituents[i].token).balanceOf(address(this)));
            if (prop < minProp) {
                minProp = prop;
            }
        }

        uint256 out = mul(totalSupply(), minProp);

        TokenIO[] memory tokensIn = new TokenIO[](constituents.length);
        for (uint256 i = 0; i < constituents.length; i++) {
            tokensIn[i].amount = mul(tokens[i].amount, ERC20(constituents[i].token).balanceOf(address(this)));
            tokensIn[i].token = tokens[i].token;
        }

        _allJoin(tokensIn, out);
    }

    /*
     * @notice all-tokens exit
     * @param _in The amount of TTC to exit
     */
    function allExit(uint256 _in) 
        external 
        _lock_
    {
        uint256 propOut = div(_in, totalSupply());
        TokenIO[] memory tokensOut = new TokenIO[](constituents.length);
        for (uint256 i = 0; i < constituents.length; i++) {
            uint256 balance = IERC20(constituents[i].token).balanceOf(address(this));
            tokensOut[i].amount = mul(balance, propOut);
            tokensOut[i].token = constituents[i].token;
        }

        _allExit(tokensOut, _in);
    }

    /*
     * @notice single-token join, takes an amount of token a user is willing to deposit
     * @param constituentIn The token to deposit
     * @param amountIn The amount of tokens to deposit
     */
    function singleJoin_AmountIn(Constituent calldata constituentIn, uint256 amountIn) 
        external 
        _lock_
        _positiveIn_(amountIn)
        _notFirstJoin_
    {
        uint256 balanceBefore = IERC20(constituentIn.token).balanceOf(address(this));
        uint256 balanceAfter = add(balanceBefore, amountIn);

        uint256 fraction = div(balanceAfter, balanceBefore);
        uint256 qP1 = powi(fraction, (constituentIn.norm));
        uint256 q = sub(qP1, ONE);

        uint256 out = mul(totalSupply(), q);

        _singleJoin(constituentIn, out, amountIn);
    }

    /*
        * @notice single-token join, takes an amount of TTC a user wants to receive
        * @notice it is a user's responsibility to check that they have enough tokens to deposit
        * @dev amountIn = B_i * (q + 1)^(1/norm) - B_i [B_i - balance of the token, q - proportion of TTC to mint, norm - norm of the token]
        * @param constituentIn The token to deposit
        * @param out The amount of TTC to receive
        */
    function singleJoin_AmountOut(Constituent calldata constituentIn, uint256 out) 
        external 
        _lock_
        _notFirstJoin_
    {
        uint256 q = div(out, totalSupply());
        uint256 power = div(1, constituentIn.norm);
        uint256 qPlus1Powered = pow(q + 1, power);
        
        uint256 balance = IERC20(constituentIn.token).balanceOf(address(this));
        uint256 mulByBalance = mul(qPlus1Powered, balance);
        uint256 amountIn = sub(mulByBalance, balance);

        _singleJoin(constituentIn, out, amountIn);
    }

    /*
        * @notice single-token exit, takes an amount of TTC a user is willing to exit
        * @dev amountOut = B_i - B_i * (1 - alpha)^(1/norm) [B_i - balance of the token, alpha - proportion of TTC to exit, norm - norm of the token]
        * @param constituentOut The token to exit
        * @param _in The amount of TTC to exit
        */
    function singleExit(Constituent calldata constituentOut, uint256 _in) 
        external 
        _lock_
        _positiveIn_(_in)
    {
        uint256 alpha = div(_in, totalSupply());
        uint oneSubAlpha = sub(ONE, alpha);

        uint256 power = div(1, constituentOut.norm);
        uint256 poweredTerm = pow(oneSubAlpha, power);

        uint256 balance = IERC20(constituentOut.token).balanceOf(address(this));
        uint256 mulBalanceTerm = mul(balance, poweredTerm);

        uint256 amountOut = sub(balance, mulBalanceTerm);

        _singleExit(constituentOut, amountOut, _in);
    }

    /*
     * @notice single-token exit, takes an amount of token a user is willing to receive
     * @param constituentOut The token to exit
     * @param amountOut The amount of tokens to receive
     */
    function _singleJoin(Constituent calldata constituentIn, uint256 out, uint256 amountIn) 
        internal 
        _isLocked_
    {
        _pullFromSender(constituentIn.token, amountIn);
        _mintSender(out);

        emit SINGLE_JOIN(msg.sender, constituentIn.token, out, amountIn);
    }

    /*
     * @notice single-token exit, takes an amount of TTC a user is willing to exit
     * @param constituentOut The token to exit
     * @param _in The amount of TTC to exit
     */
    function _singleExit(Constituent calldata constituentOut, uint256 amountOut, uint256 _in) 
        internal 
        _isLocked_
    {
        uint256 fee = amountOut * BASE_REDEMPTION_FEE / ONE;
        uint256 amountSubFee = sub(amountOut, fee);

        _pushToSender(constituentOut.token, amountSubFee);
        _burnSender(_in);

        emit SINGLE_EXIT(msg.sender, constituentOut.token, _in, amountOut);
    }

    /*
     * @notice executes an all-tokens join
     * @dev The _tokens provided MUST be of correct proportional amounts
     * @param _tokens The tokens to deposit
     * @param _amounts The amounts of tokens to deposit
     */
    function _allJoin(TokenIO[] memory _tokens, uint256 _out) 
        internal
        _isLocked_ // for safety, should only be called from locked functions to prevent reentrancy
    {
        for (uint256 i = 0; i < constituents.length; i++) {
            _pullFromSender(_tokens[i].token, _tokens[i].amount);
        }

        _mintSender(_out);
        emit ALL_JOIN(msg.sender, _out);
    }

    /*
     * @notice executes an all-tokens exit
     * @param _tokens The tokens to withdraw
     * @param _amounts The amounts of tokens to withdraw
     */
    function _allExit(TokenIO[] memory _tokens, uint256 _in) 
        internal
        _isLocked_ // for safety, should only be called from locked functions to prevent reentrancy
    {
        for (uint256 i = 0; i < constituents.length; i++) {
            uint256 fee = _tokens[i].amount * BASE_REDEMPTION_FEE / ONE;
            uint256 amountSubFee = sub(_tokens[i].amount, fee);
            
            _pushToSender(_tokens[i].token, amountSubFee);
        }

        _burnSender(_in);
        emit ALL_EXIT(msg.sender, _in);
    }

    /*
     * @notice Deposit tokens to the vault
     * @dev The caller must check that the transfer was successful
     * @param _token The token to deposit
     * @param _amount The amount of tokens to deposit
     * @return bool True if the deposit was successful
     */
    function _pullFromSender(address _token, uint256 _amount) 
        internal
    {
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));

        bool success = false;
        if (balanceAfter > balanceBefore) {
            success = true;
        }

        require(success, "ERR_TRANSFER_FAILED");
    }

    function _pushToSender(address _token, uint256 _amount) 
        internal
    {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function _checkTokensIn(TokenIO[] calldata _tokens) 
        internal 
        view 
        returns (bool) 
    {
        for (uint256 i = 0; i < constituents.length; i++) {
            if ((constituents[i].token != _tokens[i].token) || (_tokens[i].amount == 0)) { // amount should be non-zero
                return false;
            }
        }

        return true;
    }
}