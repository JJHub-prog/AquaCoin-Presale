// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AquaPresale.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SecureAquaPresaleTest is Test {
    SecureAquaPresale public presale;
    MockToken public token;

    address public owner;
    address public user1;
    address public user2;
    address public referrer;

    uint256 public constant RATE = 1000;
    uint256 public constant TOKENS_FOR_PRESALE = 1000000 * 10 ** 18;
    uint256 public constant MAX_WEI_RAISED = 1000 ether;
    uint256 public constant MIN_BUY = 0.1 ether;
    uint256 public constant MAX_BUY = 10 ether;
    uint256 public constant PRESALE_DURATION = 6 weeks;
    uint256 public constant REFERRAL_BONUS = 10; // 10%

    event TokensPurchased(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );
    event ReferralBonusAwarded(address indexed referrer, uint256 bonusAmount);
    event TokensWithdrawn(address indexed beneficiary, uint256 amount);

    function setUp() public {
        // Setup accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        referrer = makeAddr("referrer");

        // Deploy token
        vm.startPrank(owner);
        token = new MockToken();

        // Deploy presale contract
        presale = new SecureAquaPresale(
            address(token),
            RATE,
            TOKENS_FOR_PRESALE,
            MAX_WEI_RAISED,
            MIN_BUY,
            MAX_BUY,
            PRESALE_DURATION,
            REFERRAL_BONUS
        );

        // Fund presale contract with tokens
        token.mint(address(presale), TOKENS_FOR_PRESALE);
        vm.stopPrank();

        // Fund test users with ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testInitialState() public view {
        assertEq(address(presale.aquaToken()), address(token));
        assertEq(presale.rate(), RATE);
        assertEq(presale.tokensForPresale(), TOKENS_FOR_PRESALE);
        assertEq(presale.maxWeiRaised(), MAX_WEI_RAISED);
        assertEq(presale.minBuy(), MIN_BUY);
        assertEq(presale.maxBuy(), MAX_BUY);
        assertEq(presale.referralBonusPercentage(), REFERRAL_BONUS);
    }

    function testTokenPurchase() public {
        uint256 purchaseAmount = 1 ether;
        uint256 expectedTokens = purchaseAmount * RATE;

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit TokensPurchased(user1, user1, purchaseAmount, expectedTokens);
        presale.buyTokens{value: purchaseAmount}(user1, address(0));

        assertEq(presale.getPendingWithdrawal(user1), expectedTokens);
        assertEq(presale.weiRaised(), purchaseAmount);
    }

    function testPurchaseWithReferral() public {
        uint256 purchaseAmount = 1 ether;
        uint256 expectedTokens = purchaseAmount * RATE;
        uint256 expectedReferralBonus = (expectedTokens * REFERRAL_BONUS) / 100;

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit TokensPurchased(user1, user1, purchaseAmount, expectedTokens);
        emit ReferralBonusAwarded(referrer, expectedReferralBonus);
        presale.buyTokens{value: purchaseAmount}(user1, referrer);

        assertEq(presale.getPendingWithdrawal(user1), expectedTokens);
        assertEq(presale.getReferralReward(referrer), expectedReferralBonus);
    }

    function testClaimTokens() public {
        // First purchase tokens
        uint256 purchaseAmount = 1 ether;
        vm.prank(user1);
        presale.buyTokens{value: purchaseAmount}(user1, address(0));

        // Then claim them
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit TokensWithdrawn(user1, purchaseAmount * RATE);
        presale.claimTokens();

        assertEq(token.balanceOf(user1), purchaseAmount * RATE);
        assertEq(presale.getPendingWithdrawal(user1), 0);
    }

    function testClaimReferralRewards() public {
        // First make a purchase with referral
        uint256 purchaseAmount = 1 ether;
        vm.prank(user1);
        presale.buyTokens{value: purchaseAmount}(user1, referrer);

        uint256 expectedReferralBonus = (purchaseAmount *
            RATE *
            REFERRAL_BONUS) / 100;

        // Then claim referral rewards
        vm.prank(referrer);
        vm.expectEmit(true, false, false, true);
        emit TokensWithdrawn(referrer, expectedReferralBonus);
        presale.claimReferralRewards();

        assertEq(token.balanceOf(referrer), expectedReferralBonus);
        assertEq(presale.getReferralReward(referrer), 0);
    }

    function testPauseAndUnpause() public {
        // Pause the contract
        vm.prank(owner);
        presale.pause();

        // Try to purchase tokens while paused
        uint256 purchaseAmount = 1 ether;
        vm.prank(user1);
        vm.expectRevert("Pausable: paused");
        presale.buyTokens{value: purchaseAmount}(user1, address(0));

        // Unpause and verify purchase works
        vm.prank(owner);
        presale.unpause();

        vm.prank(user1);
        presale.buyTokens{value: purchaseAmount}(user1, address(0));

        assertEq(presale.getPendingWithdrawal(user1), purchaseAmount * RATE);
    }

    function testFailPurchaseBelowMin() public {
        uint256 purchaseAmount = MIN_BUY - 0.01 ether;
        vm.prank(user1);
        presale.buyTokens{value: purchaseAmount}(user1, address(0));
    }

    function testFailPurchaseAboveMax() public {
        uint256 purchaseAmount = MAX_BUY + 0.01 ether;
        vm.prank(user1);
        presale.buyTokens{value: purchaseAmount}(user1, address(0));
    }

    function testEmergencyWithdraw() public {
        // First make some purchases
        uint256 purchaseAmount = 1 ether;
        vm.prank(user1);
        presale.buyTokens{value: purchaseAmount}(user1, address(0));

        // Record balances before emergency withdraw
        uint256 contractEthBalance = address(presale).balance;
        uint256 contractTokenBalance = token.balanceOf(address(presale));
        uint256 ownerEthBalanceBefore = address(owner).balance;
        uint256 ownerTokenBalanceBefore = token.balanceOf(owner);

        // Perform emergency withdraw
        vm.prank(owner);
        presale.emergencyWithdraw();

        // Verify balances
        assertEq(address(presale).balance, 0);
        assertEq(token.balanceOf(address(presale)), 0);
        assertEq(
            address(owner).balance,
            ownerEthBalanceBefore + contractEthBalance
        );
        assertEq(
            token.balanceOf(owner),
            ownerTokenBalanceBefore + contractTokenBalance
        );
    }

    function testUpdatePresaleParameters() public {
        uint256 newRate = 2000;
        uint256 newMaxWeiRaised = 2000 ether;
        uint256 newTokensForPresale = 2000000 * 10 ** 18;
        uint256 newMinBuy = 0.2 ether;
        uint256 newMaxBuy = 20 ether;
        uint256 newReferralBonus = 15;

        vm.prank(owner);
        presale.updatePresaleParameters(
            newRate,
            newMaxWeiRaised,
            newTokensForPresale,
            newMinBuy,
            newMaxBuy,
            newReferralBonus
        );

        assertEq(presale.rate(), newRate);
        assertEq(presale.maxWeiRaised(), newMaxWeiRaised);
        assertEq(presale.tokensForPresale(), newTokensForPresale);
        assertEq(presale.minBuy(), newMinBuy);
        assertEq(presale.maxBuy(), newMaxBuy);
        assertEq(presale.referralBonusPercentage(), newReferralBonus);
    }

    function testFuzzPurchase(uint256 purchaseAmount) public {
        // Bound the purchase amount between MIN_BUY and MAX_BUY
        purchaseAmount = bound(purchaseAmount, MIN_BUY, MAX_BUY);

        vm.assume(purchaseAmount <= MAX_WEI_RAISED);

        // Fund the user with exact purchase amount
        vm.deal(user1, purchaseAmount);

        vm.prank(user1);
        presale.buyTokens{value: purchaseAmount}(user1, address(0));

        assertEq(presale.getPendingWithdrawal(user1), purchaseAmount * RATE);
        assertEq(presale.weiRaised(), purchaseAmount);
    }

    receive() external payable {} // Allow contract to receive ETH
}
