// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/AquaPresale.sol";
import "../src/MockToken.sol";

contract DeployScript is Script {
    // Deployment configuration
    uint256 public constant RATE = 1000; // 1 ETH = 1000 tokens
    uint256 public constant TOKENS_FOR_PRESALE = 1_000_000 * 1e18; // 1 million tokens
    uint256 public constant MAX_WEI_RAISED = 1000 ether; // 1000 ETH cap
    uint256 public constant MIN_BUY = 0.1 ether; // Minimum 0.1 ETH
    uint256 public constant MAX_BUY = 10 ether; // Maximum 10 ETH
    uint256 public constant PRESALE_DURATION = 6 weeks;
    uint256 public constant REFERRAL_BONUS = 10; // 10% referral bonus

    function run() external {
        // Fetch deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockToken first
        MockAquaToken token = new MockAquaToken();
        console.log("Token deployed to:", address(token));

        // Mint initial supply to deployer
        token.mint(vm.addr(deployerPrivateKey), TOKENS_FOR_PRESALE * 2); // Mint extra for testing
        console.log("Tokens minted to deployer:", TOKENS_FOR_PRESALE * 2);

        // Deploy the presale contract
        SecureAquaPresale presale = new SecureAquaPresale(
            address(token),
            RATE,
            TOKENS_FOR_PRESALE,
            MAX_WEI_RAISED,
            MIN_BUY,
            MAX_BUY,
            PRESALE_DURATION,
            REFERRAL_BONUS
        );
        console.log("Presale deployed to:", address(presale));

        // Approve and transfer tokens to presale contract
        token.approve(address(presale), TOKENS_FOR_PRESALE);
        token.transfer(address(presale), TOKENS_FOR_PRESALE);
        console.log("Tokens transferred to presale:", TOKENS_FOR_PRESALE);

        // Verify setup
        uint256 presaleBalance = token.balanceOf(address(presale));
        console.log("Presale contract token balance:", presaleBalance);

        vm.stopBroadcast();

        // Log deployment information
        console.log("\nDeployment Summary");
        console.log("==================");
        console.log("Token Address:", address(token));
        console.log("Presale Address:", address(presale));
        console.log("Deployer Address:", vm.addr(deployerPrivateKey));
        console.log("\nPresale Configuration");
        console.log("-------------------");
        console.log("Rate:", RATE);
        console.log("Tokens for Presale:", TOKENS_FOR_PRESALE);
        console.log("Max Wei Raised:", MAX_WEI_RAISED);
        console.log("Min Buy:", MIN_BUY);
        console.log("Max Buy:", MAX_BUY);
        console.log("Presale Duration:", PRESALE_DURATION / 1 days, "days");
        console.log("Referral Bonus:", REFERRAL_BONUS, "%");
        
        string memory filename = "deployment.json";
        string memory deploymentInfo = string(
            abi.encodePacked(
                '{"token":"', vm.toString(address(token)),
                '","presale":"', vm.toString(address(presale)),
                '","deployer":"', vm.toString(vm.addr(deployerPrivateKey)), '"}'
            )
        );
        vm.writeFile(filename, deploymentInfo);
        console.log("\nDeployment information saved to", filename);
    }
}