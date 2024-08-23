// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__ZeroBalance();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__ZeroAddress();

    constructor() ERC20("PKRSStablecoin", "PKRS") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (balance <= 0) {
            revert DecentralizedStableCoin__ZeroBalance();
        }
        if (_amount > balance) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__ZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__ZeroBalance();
        }
        _mint(_to, _amount);
        return true;
    }
}
