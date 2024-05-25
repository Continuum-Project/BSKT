// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TTCConstants.sol";

contract TTC is ERC20, TTCConstants, Ownable {
    constructor() ERC20(TTC_NAME, TTC_SYMBOL) Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /*
     * @notice Mint tokens to the sender
     * @param _amount The amount of tokens to mint
     */
    function mintSender(uint256 _amount) 
        external
        onlyOwner
    {
        _mint(msg.sender, _amount);
    }

    /*
     * @notice Burn tokens from the sender
     * @param _amount The amount of tokens to burn
     */
    function burnSender(uint256 _amount) 
        external
        onlyOwner
    {
        _burn(msg.sender, _amount);
    }
}