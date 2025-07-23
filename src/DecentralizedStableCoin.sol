// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "@openzepplin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzepplin-contracts/contracts/access/Ownable.sol";

/*
 * @title: DecentralizedStableCoin
 * @author: Yousef Medhat
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 implementation of our stablecoin system.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AddressZero();
    error DecentralizedStableCoin__AmountLessThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();

    constructor() ERC20("DecentralizedStableCoin", "DSC") {}

    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        if (to == address(0)) {
            revert DecentralizedStableCoin__AddressZero();
        }
        if (amount <= 0) {
            revert DecentralizedStableCoin__AmountLessThanZero();
        }

        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = this.balanceOf(msg.sender);
        if (amount <= 0) {
            revert DecentralizedStableCoin__AmountLessThanZero();
        }
        if (amount > balance) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }

        super.burn(amount);
    }
}
