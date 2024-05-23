// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TTC.sol";
import "../types/Types.sol";

contract TTCVault is TTC {
    event ALL_JOIN (
        address indexed sender,
        uint256 out
    );

    event ALL_EXIT (
        address indexed sender,
        uint256 inp
    );

    modifier _lock_() {
        require(!_lock, "ERR_REENTRANCY");
        _lock = true;
        _;
        _lock = false;
    }

    modifier _validTokensIn(TokenIO[] calldata _tokens) {
        require(_checkTokensIn(_tokens), "ERR_INVALID_TOKENS");
        _;
    }

    modifier _isLocked() {
        require(_lock, "ERR_NOT_LOCKED");
        _;
    }

    bool private _lock;
    Constituent[] public constituents;

    constructor(Constituent[] memory initialConstituents) {
        for (uint256 i = 0; i < initialConstituents.length; i++) {
            constituents.push(initialConstituents[i]);
        }
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
    {
        uint256 propIn = out * BONE / totalSupply(); // the proportion of each token to deposit in order to get "out" amount
        TokenIO[] memory tokensIn = new TokenIO[](constituents.length);
        for (uint256 i = 0; i < constituents.length; i++) {
            uint256 balance = IERC20(constituents[i].token).balanceOf(address(this));
            tokensIn[i].amount = balance * propIn / BONE;
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
        _validTokensIn(tokens)
    {
        uint256 minProp = type(uint256).max;
        for (uint256 i = 0; i < constituents.length; i++) {
            uint256 prop = tokens[i].amount * BONE / ERC20(constituents[i].token).balanceOf(address(this));
            if (prop < minProp) {
                minProp = prop;
            }
        }

        uint256 out = totalSupply() * minProp / BONE;

        TokenIO[] memory tokensIn = new TokenIO[](constituents.length);
        for (uint256 i = 0; i < constituents.length; i++) {
            tokensIn[i].amount = tokens[i].amount * ERC20(constituents[i].token).balanceOf(address(this)) / BONE;
            tokensIn[i].token = tokens[i].token;
        }

        _allJoin(tokensIn, out);
    }

    function AllExit(uint256 _in) 
        external 
        _lock_
    {
        uint256 propOut = _in * BONE / totalSupply();
        TokenIO[] memory tokensOut = new TokenIO[](constituents.length);
        for (uint256 i = 0; i < constituents.length; i++) {
            uint256 balance = IERC20(constituents[i].token).balanceOf(address(this));
            tokensOut[i].amount = balance * propOut / BONE;
            tokensOut[i].token = constituents[i].token;
        }

        _allExit(tokensOut, _in);
    }

    /*
     * @notice executes an all-tokens join
     * @dev The _tokens provided MUST be of correct proportional amounts
     * @param _tokens The tokens to deposit
     * @param _amounts The amounts of tokens to deposit
     */
    function _allJoin(TokenIO[] memory _tokens, uint256 _out) 
        internal
        _isLocked // for safety, should only be called from locked functions to prevent reentrancy
    {
        for (uint256 i = 0; i < constituents.length; i++) {
            _pullFromSender(_tokens[i].token, _tokens[i].amount);
        }

        _mintSender(_out);
        emit ALL_JOIN(msg.sender, _out);
    }

    function _allExit(TokenIO[] memory _tokens, uint256 _in) 
        internal
        _isLocked // for safety, should only be called from locked functions to prevent reentrancy
    {
        for (uint256 i = 0; i < constituents.length; i++) {
            _pushToSender(_tokens[i].token, _tokens[i].amount);
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
        returns(bool)
    {
        bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        return success;
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
            if ((constituents[i].token == _tokens[i].token) || (_tokens[i].amount == 0)) { // amount should be non-zero
                return false;
            }
        }

        return true;
    }
}