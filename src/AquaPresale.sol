// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SecureAquaPresale is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // State variables
    IERC20 public aquaToken;
    uint256 public rate;
    uint256 public weiRaised;
    uint256 public tokensForPresale;
    uint256 public tokensSold;
    uint256 public maxWeiRaised;
    uint256 public minBuy;
    uint256 public maxBuy;
    uint256 public immutable presaleStartTime;
    uint256 public presaleEndTime;
    uint256 public referralBonusPercentage;

    // Mappings
    mapping(address => uint256) public referralRewards;
    mapping(address => uint256) private pendingWithdrawals;

    // Events
    event TokensPurchased(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );
    event ReferralBonusAwarded(address indexed referrer, uint256 bonusAmount);
    event TokenAddressUpdated(
        address indexed oldToken,
        address indexed newToken
    );
    event PresaleParametersUpdated(
        uint256 newRate,
        uint256 newMaxWeiRaised,
        uint256 newTokensForPresale,
        uint256 newMinBuy,
        uint256 newMaxBuy,
        uint256 newReferralBonus
    );
    event TokensWithdrawn(address indexed beneficiary, uint256 amount);
    event PresaleTimeUpdated(uint256 newEndTime);
    event EmergencyWithdraw(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    // Custom errors
    error PresaleNotActive();
    error InvalidAmount();
    error MaxCapExceeded();
    error InsufficientContractBalance();
    error InvalidBeneficiary();
    error InvalidParameters();
    error WithdrawalFailed();

    constructor(
        address _token,
        uint256 _rate,
        uint256 _tokensForPresale,
        uint256 _maxWeiRaised,
        uint256 _minBuy,
        uint256 _maxBuy,
        uint256 _presaleDuration,
        uint256 _referralBonusPercentage
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        require(_rate > 0, "Rate must be greater than 0");
        require(
            _tokensForPresale > 0,
            "Tokens for presale must be greater than 0"
        );
        require(_maxWeiRaised > 0, "Max wei raised must be greater than 0");
        require(_minBuy < _maxBuy, "Min buy must be less than max buy");
        require(
            _referralBonusPercentage <= 100,
            "Invalid referral bonus percentage"
        );

        aquaToken = IERC20(_token);
        rate = _rate;
        tokensForPresale = _tokensForPresale;
        maxWeiRaised = _maxWeiRaised;
        minBuy = _minBuy;
        maxBuy = _maxBuy;
        referralBonusPercentage = _referralBonusPercentage;
        presaleStartTime = block.timestamp;
        presaleEndTime = block.timestamp + _presaleDuration;
    }

    // Modifiers
    modifier presaleActive() {
        if (
            block.timestamp < presaleStartTime ||
            block.timestamp > presaleEndTime
        ) revert PresaleNotActive();
        _;
    }

    // Main functions
    function buyTokens(
        address beneficiary,
        address referrer
    ) public payable nonReentrant whenNotPaused presaleActive {
        // Validations
        if (beneficiary == address(0)) revert InvalidBeneficiary();
        if (msg.value == 0) revert InvalidAmount();
        if (weiRaised + msg.value > maxWeiRaised) revert MaxCapExceeded();

        // Calculate tokens
        uint256 tokens = _getTokenAmount(msg.value);
        if (tokens < minBuy || tokens > maxBuy) revert InvalidAmount();
        if (tokensSold + tokens > tokensForPresale) revert MaxCapExceeded();

        // Calculate referral bonus
        uint256 referralBonus = 0;
        if (referrer != address(0) && referrer != beneficiary) {
            referralBonus = (tokens * referralBonusPercentage) / 100;
            if (tokensSold + tokens + referralBonus <= tokensForPresale) {
                referralRewards[referrer] += referralBonus;
                emit ReferralBonusAwarded(referrer, referralBonus);
            }
        }

        // Update state
        weiRaised += msg.value;
        tokensSold += tokens + referralBonus;
        pendingWithdrawals[beneficiary] += tokens;

        emit TokensPurchased(msg.sender, beneficiary, msg.value, tokens);
    }

    function claimTokens() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert InvalidAmount();

        // Check contract balance
        uint256 contractBalance = aquaToken.balanceOf(address(this));
        if (contractBalance < amount) revert InsufficientContractBalance();

        // Update state before transfer
        pendingWithdrawals[msg.sender] = 0;

        // Perform transfer
        aquaToken.safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, amount);
    }

    function claimReferralRewards() external nonReentrant {
        uint256 amount = referralRewards[msg.sender];
        if (amount == 0) revert InvalidAmount();

        // Check contract balance
        uint256 contractBalance = aquaToken.balanceOf(address(this));
        if (contractBalance < amount) revert InsufficientContractBalance();

        // Update state before transfer
        referralRewards[msg.sender] = 0;

        // Perform transfer
        aquaToken.safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, amount);
    }

    // Admin functions
    function updatePresaleParameters(
        uint256 _rate,
        uint256 _maxWeiRaised,
        uint256 _tokensForPresale,
        uint256 _minBuy,
        uint256 _maxBuy,
        uint256 _referralBonusPercentage
    ) external onlyOwner {
        if (
            _rate == 0 ||
            _maxWeiRaised == 0 ||
            _tokensForPresale == 0 ||
            _minBuy >= _maxBuy ||
            _referralBonusPercentage > 100
        ) revert InvalidParameters();

        rate = _rate;
        maxWeiRaised = _maxWeiRaised;
        tokensForPresale = _tokensForPresale;
        minBuy = _minBuy;
        maxBuy = _maxBuy;
        referralBonusPercentage = _referralBonusPercentage;

        emit PresaleParametersUpdated(
            _rate,
            _maxWeiRaised,
            _tokensForPresale,
            _minBuy,
            _maxBuy,
            _referralBonusPercentage
        );
    }

    function updatePresaleEndTime(uint256 _newEndTime) external onlyOwner {
        if (_newEndTime <= block.timestamp) revert InvalidParameters();
        presaleEndTime = _newEndTime;
        emit PresaleTimeUpdated(_newEndTime);
    }

    function emergencyWithdraw() external onlyOwner {
        // Withdraw tokens
        uint256 tokenBalance = aquaToken.balanceOf(address(this));
        if (tokenBalance > 0) {
            aquaToken.safeTransfer(owner(), tokenBalance);
            emit EmergencyWithdraw(address(aquaToken), owner(), tokenBalance);
        }

        // Withdraw ETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = owner().call{value: ethBalance}("");
            if (!success) revert WithdrawalFailed();
            emit EmergencyWithdraw(address(0), owner(), ethBalance);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Internal functions
    function _getTokenAmount(
        uint256 weiAmount
    ) internal view returns (uint256) {
        return weiAmount * rate;
    }

    // View functions
    function getContractBalance() external view returns (uint256) {
        return aquaToken.balanceOf(address(this));
    }

    function getPendingWithdrawal(
        address user
    ) external view returns (uint256) {
        return pendingWithdrawals[user];
    }

    function getReferralReward(address user) external view returns (uint256) {
        return referralRewards[user];
    }

    // Fallback functions
    receive() external payable {
        buyTokens(msg.sender, address(0));
    }

    fallback() external payable {
        buyTokens(msg.sender, address(0));
    }
}
