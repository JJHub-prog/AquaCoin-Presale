
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/utils/Pausable.sol";

// contract CustomERC20 is ERC20, ERC20Burnable, AccessControl, Pausable {
//     bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
//     bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

//     constructor(string memory name, string memory symbol) ERC20(name, symbol) {
//         // Grant the deployer the default admin role, minter role, and pauser role
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         _grantRole(MINTER_ROLE, msg.sender);
//         _grantRole(PAUSER_ROLE, msg.sender);
//     }

//     /**
//      * @notice Mints tokens to a specified address
//      * @dev Only accounts with the MINTER_ROLE can call this function
//      * @param to The address to mint tokens to
//      * @param amount The amount of tokens to mint
//      */
//     function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
//         _mint(to, amount);
//     }

//     /**
//      * @notice Pauses all token transfers
//      * @dev Only accounts with the PAUSER_ROLE can call this function
//      */
//     function pause() public onlyRole(PAUSER_ROLE) {
//         _pause();
//     }

//     /**
//      * @notice Unpauses all token transfers
//      * @dev Only accounts with the PAUSER_ROLE can call this function
//      */
//     function unpause() public onlyRole(PAUSER_ROLE) {
//         _unpause();
//     }

//     /**
//      * @dev Overrides the _beforeTokenTransfer function to include the "whenNotPaused" modifier
//      */
    

//     // function _beforeTokenTransfer(address from, address to, uint256 amount)
//     //     internal
//     //     override
//     // {
//     //     super._beforeTokenTransfer(from, to, amount);  // Calls the ERC20 implementation of _beforeTokenTransfer
//     //     require(!paused(), "Token transfers are paused");
//     // }
// }


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract CustomERC20 is ERC20, ERC20Burnable, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Grant the deployer the default admin role, minter role, and pauser role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @notice Mints tokens to a specified address
     * @dev Only accounts with the MINTER_ROLE can call this function
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Pauses all token transfers
     * @dev Only accounts with the PAUSER_ROLE can call this function
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all token transfers
     * @dev Only accounts with the PAUSER_ROLE can call this function
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Override _beforeTokenTransfer to include pausing functionality
     * Since OpenZeppelin 5.2.0 removed _beforeTokenTransfer in ERC20, we need to define it ourselves.
     * This method will prevent transfers when the contract is paused.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) // address from, address to, uint256 amount
        internal
        
    {
        // Add pausing check here
        require(!paused(), "Token transfers are paused");
        // You can add any additional logic here for before token transfer
    }
}
