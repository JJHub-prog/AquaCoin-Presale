// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockAquaToken is ERC20, Ownable {
    uint256 private constant TOTAL_SUPPLY = 200000000 * 10 ** 18; // 200 million tokens with 18 decimals

    constructor() ERC20("Aqua Token", "AQUA") Ownable(msg.sender) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    // Optional: Add a mint function for testing purposes
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // Optional: Add a burn function for testing purposes
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
