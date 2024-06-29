// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./TTC.sol";
import "../types/CVault.sol";
import "../types/CBounty.sol";
import "./TTCMath.sol";
import "../interface/ITTCVault.sol";
import "./TTCFees.sol";
import "../dao/CBounty.sol";
import "../periphery/cstETH.sol";
import "../interface/IFeeCollectable.sol";

contract TTCVault is ITTCVault, TTCMath, TTCFees, Ownable {
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

    modifier _positiveInput_(uint256 _in) {
        require(_in > 0, "ERR_ZERO_IN");
        _;
    }

    modifier _supplyNonZero_() {
        require(i_ttc.totalSupply() > 0, "ERR_SUPPLY_IS_ZERO");
        _;
    }

    bool private _locked;
    Constituent[] public s_constituents;
    BountyContract public immutable i_bountyContract;
    TTC public immutable i_ttc;

    constructor(Constituent[] memory initials_constituents, address bountyAddress, address ttcAddress)
        Ownable(msg.sender)
    {
        for (uint256 i = 0; i < initials_constituents.length; i++) {
            s_constituents.push(initials_constituents[i]);
        }

        i_bountyContract = BountyContract(bountyAddress);
        i_ttc = TTC(ttcAddress); // sets the vault as the Owner of TTC

        // set the block of creation as the first block into the blockstamps array
        recordAnnualFeeBlockstamp();
    }

    function allJoin_Initial(TokenIO[] calldata tokens) external _lock_ {
        require(i_ttc.totalSupply() == 0, "ERR_NOT_FIRST_JOIN");
        _allJoin(tokens, 10 ** i_ttc.decimals()); // mint 1 TTC, sets the initial price
    }

    /*
     * @notice all-tokens join, providing the desired amount of TTC out
     * @notice It is responsibility of a caller to check that they have the correct amount of tokens
     * @param _tokens The tokens to deposit
     * @param _amounts The amounts of tokens to deposit
     */
    function allJoin_Out(uint256 out) external _lock_ _supplyNonZero_ {
        _allJoin_Out(out);
    }

    /*
     * @notice all-tokens join, providing the list of tokens a sender is willing to deposit, the contract searches for the best all-tokens join
     * @param _tokens The tokens to deposit
     * @param _amounts The amounts of tokens to deposit
     */
    function allJoin_Min(TokenIO[] calldata tokens) external _lock_ _validTokensIn_(tokens) _supplyNonZero_ {
        uint256 minProp = type(uint256).max;
        for (uint256 i = 0; i < s_constituents.length; i++) {
            uint256 prop = div(tokens[i].amount, ERC20(s_constituents[i].token).balanceOf(address(this)));
            if (prop < minProp) {
                minProp = prop;
            }
        }

        uint256 out = mul(i_ttc.totalSupply(), minProp);
        _allJoin_Out(out);
    }

    /*
     * @notice all-tokens exit
     * @param _in The amount of TTC to exit
     */
    function allExit(uint256 _in) external _lock_ _positiveInput_(_in) {
        uint256 propOut = div(_in, i_ttc.totalSupply());
        uint256 sizeOut = s_constituents.length;
        TokenIO[] memory tokensOut = new TokenIO[](sizeOut);
        for (uint256 i = 0; i < sizeOut; i++) {
            uint256 balance = IERC20(s_constituents[i].token).balanceOf(address(this));
            tokensOut[i].amount = mul(balance, propOut);
            tokensOut[i].token = s_constituents[i].token;
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
        _positiveInput_(amountIn)
        _supplyNonZero_
    {
        uint256 balanceBefore = IERC20(constituentIn.token).balanceOf(address(this));
        uint256 balanceAfter = add(balanceBefore, amountIn);

        uint256 fraction = div(balanceAfter, balanceBefore);
        uint256 qP1 = pow(fraction, constituentIn.norm * ONE / 100);
        uint256 q = sub(qP1, ONE);

        uint256 out = mul(i_ttc.totalSupply(), q);

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
        _supplyNonZero_
        _positiveInput_(out)
    {
        uint256 q = div(out, i_ttc.totalSupply());
        require(q < ONE, "ERR_FRACTION_OUT_TOO_HIGH");

        uint256 qP1 = add(q, ONE);
        uint256 power = 100 * ONE / constituentIn.norm;
        uint256 qPlus1Powered = pow(qP1, power);

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
    function singleExit(Constituent calldata constituentOut, uint256 _in) external _lock_ _positiveInput_(_in) {
        uint256 alpha = div(_in, i_ttc.totalSupply());
        uint256 oneSubAlpha = sub(ONE, alpha);

        uint256 power = 100 * ONE / constituentOut.norm;
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
    function _singleJoin(Constituent calldata constituentIn, uint256 _out, uint256 amountIn) internal _isLocked_ {
        _pullFromSender(constituentIn.token, amountIn);
        i_ttc.mint(msg.sender, _out);

        emit SINGLE_JOIN(msg.sender, constituentIn.token, _out, amountIn);
    }

    /*
     * @notice single-token exit, takes an amount of TTC a user is willing to exit
     * @param constituentOut The token to exit
     * @param _in The amount of TTC to exit
     */
    function _singleExit(Constituent calldata constituentOut, uint256 amountOut, uint256 _in) internal _isLocked_ {
        // for a single token exit, the fee is only charged on the amount of tokens that are beyond balance
        uint256 amountOutSubFee = chargeBaseFeePlusMarginal(amountOut, constituentOut.norm);

        _pushToSender(constituentOut.token, amountOutSubFee);
        i_ttc.burn(msg.sender, _in);

        emit SINGLE_EXIT(msg.sender, constituentOut.token, _in, amountOutSubFee);
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
        for (uint256 i = 0; i < s_constituents.length; i++) {
            _pullFromSender(_tokens[i].token, _tokens[i].amount);
        }

        i_ttc.mint(msg.sender, _out);
        emit ALL_JOIN(msg.sender, _out);
    }

    function _allJoin_Out(uint256 out) internal _isLocked_ {
        uint256 propIn = div(out, i_ttc.totalSupply()); // the proportion of each token to deposit in order to get "out" amount
        uint256 sizeIn = s_constituents.length;
        TokenIO[] memory tokensIn = new TokenIO[](sizeIn);
        for (uint256 i = 0; i < sizeIn; i++) {
            uint256 balance = IERC20(s_constituents[i].token).balanceOf(address(this));
            tokensIn[i].amount = mul(balance, propIn);
            tokensIn[i].token = s_constituents[i].token;
        }

        _allJoin(tokensIn, out);
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
        for (uint256 i = 0; i < s_constituents.length; i++) {
            uint256 amountSubFee = chargeBaseFee(_tokens[i].amount);

            _pushToSender(_tokens[i].token, amountSubFee);
        }

        i_ttc.burn(msg.sender, _in);
        emit ALL_EXIT(msg.sender, _in);
    }

    /*
     * @notice Deposit tokens to the vault
     * @dev The caller must check that the transfer was successful
     * @param _token The token to deposit
     * @param _amount The amount of tokens to deposit
     * @return bool True if the deposit was successful
     */
    function _pullFromSender(address _token, uint256 _amount) internal {
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));

        bool success = false;
        if (balanceAfter > balanceBefore) {
            success = true;
        }

        require(success, "ERR_TRANSFER_FAILED");
    }

    function _pushToSender(address _token, uint256 _amount) internal {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function _checkTokensIn(TokenIO[] calldata _tokens) internal view returns (bool) {
        for (uint256 i = 0; i < s_constituents.length; i++) {
            if ((s_constituents[i].token != _tokens[i].token) || (_tokens[i].amount == 0)) {
                // amount should be non-zero
                return false;
            }
        }

        return true;
    }

    // ------------------ ADMIN FUNCTIONS ------------------

    /*
    * @notice Charge the annual fee of 0.9%
    * Anyone can call this function, but it can only be called once per year
    * The fee is always sent to the owner of the vault (DAO)
    */
    function chargeAnnualFee() public {
        require(annualFeeBlockstamps[annualFeeBlockstamps.length - 1] + ANNUAL_FEE_PERIOD < block.number, "ERR_FEE_ALREADY_CHARGED");
        
        for (uint256 i = 0; i < s_constituents.length; i++) {
            uint256 balance = IERC20(s_constituents[i].token).balanceOf(address(this));
            uint256 fee = balance * ANNUAL_FEE / ONE;
            IERC20(s_constituents[i].token).transfer(owner(), fee);
        }
        
        recordAnnualFeeBlockstamp();
    }

    function createBounty(uint256 amountGive, address tokenGive, address tokenWant)
        external
        onlyOwner
        returns (uint256)
    {
        return i_bountyContract.createBounty(tokenWant, tokenGive, amountGive);
    }

    function fulfillBounty(uint256 _bountyId, uint256 amountIn) external onlyOwner {
        // approve the bounty contract to transfer the tokens
        Bounty memory bounty = i_bountyContract.getBounty(_bountyId);
        IERC20(bounty.tokenGive).approve(address(i_bountyContract), bounty.amountGive);

        i_bountyContract.fulfillBounty(_bountyId, amountIn);
    }

    /*
     * @notice Modify the constituents of the vault
     * @param newConstituents The new constituents of the vault
     */
    function modifyConstituents(Constituent[] calldata newConstituents) external onlyOwner {
        for (uint256 i = 0; i < newConstituents.length; i++) {
            s_constituents[i] = newConstituents[i];
        }
    }

    /*
     * @dev does not check if the token is a fee collectable token, should be done by dao
     * @notice Collect the yield from a fee collectable token
     * @param _token The token to collect the yield from
     */
    function collectYield(address _token) external onlyOwner {
        IFeeCollectable feeCollectable = IFeeCollectable(_token);
        feeCollectable.collectFee();
    }

    function addPriceFeed(address _token, address _dataFeed) external onlyOwner {
        i_bountyContract.addPriceFeed(_token, _dataFeed);
    }

    // ------------ QUERIES ------------

    function constituentsLength() external view returns (uint256) {
        return s_constituents.length;
    }

    function getTokenWeight(address _token) external view returns (uint8) {
        for (uint256 i = 0; i < s_constituents.length; i++) {
            if (s_constituents[i].token == _token) {
                return s_constituents[i].norm;
            }
        }

        return 0;
    }
}
