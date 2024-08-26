// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
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
// internal & private view & pure functions
// external & public view & pure functions

/**
 * @title PKRSEngine
 * @dev A contract for managing collateral deposits and minting a decentralized stablecoin (PKRS).
 * @author DSC Engine
 *
 * @notice This contract allows users to deposit collateral, mint PKRS tokens, redeem collateral,
 * and perform other operations related to the decentralized stablecoin.
 */
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PKRSEngine is ReentrancyGuard {
    ////////////////////////
    /// Custom Errors ///
    ////////////////////////

    error PKRSEngine__ZeroAmount();
    error PKRSEngine__InvalidCollateralToken();
    error PKRSEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
    error PKRSEngine__TransferFailed();
    error PKRSEngine__BreaksHealthFactor(uint256 _healthFactor);
    error PKRSEngine__MintFailed();
    error PKRSEngine__HealthFactorOK();
    error PKRSEngine__HealthFactorNotImproved();

    //////////////////////////
    /// State Variables ///
    //////////////////////////

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountPKRSMinted) private s_PKRSMinted;
    address[] private s_collateralTokens;

    ///////////////////////
    /// Events ///
    ///////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount); // Event emitted when collateral is deposited
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // if
        // redeemFrom != redeemedTo, then it was liquidated

    ////////////////////////////
    /// Immutable Variables ///
    ////////////////////////////

    DecentralizedStableCoin private immutable i_pkrsToken; // The PKRS token (Decentralized StableCoin)

    //////////////////////
    /// Modifiers ///
    //////////////////////

    modifier nonZeroAmount(uint256 _amount) {
        // Ensures the amount is not zero
        if (_amount == 0) {
            revert PKRSEngine__ZeroAmount();
        }
        _;
    }

    modifier isAllowedCollateralToken(address _token) {
        // Ensures the token is a valid collateral token
        if (s_priceFeeds[_token] == address(0)) {
            revert PKRSEngine__InvalidCollateralToken();
        }
        _;
    }

    ///////////////////////////////////////
    /// Constructor ///
    ///////////////////////////////////////

    /**
     * @dev Constructor to initialize the contract with token and price feed addresses, and PKRS token address.
     * @param _tokenAddresses The addresses of collateral tokens.
     * @param _priceFeedAddresses The addresses of the corresponding price feeds for the collateral tokens.
     * @param _PKRSAddress The address of the PKRS token (Decentralized StableCoin).
     */
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address _PKRSAddress) {
        // Ensure token and price feed arrays have the same length
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert PKRSEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
        }
        // Map each token to its respective price feed
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeeds[_tokenAddresses[i]] = _priceFeedAddresses[i];
            s_collateralTokens.push(_tokenAddresses[i]);
        }
        // Set the PKRS token address
        i_pkrsToken = DecentralizedStableCoin(_PKRSAddress);
    }

    //////////////////////////////////////
    /// External Functions ///
    //////////////////////////////////////

    /**
     * @dev Deposit collateral for a specific token.
     * @param _tokenCollateralAddress The address of the collateral token.
     * @param _amountCollateral The amount of collateral to deposit.
     */
    function depositCollateral(address _tokenCollateralAddress, uint256 _amountCollateral)
        public
        nonZeroAmount(_amountCollateral)
        isAllowedCollateralToken(_tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _amountCollateral;
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _amountCollateral);
        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _amountCollateral);
        if (!success) {
            revert PKRSEngine__TransferFailed();
        }
    }

    /**
     * @dev Redeem collateral for PKRS tokens (not yet implemented).
     */
    function redeemCollateralForPKRS(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
        nonZeroAmount(amountCollateral)
        isAllowedCollateralToken(tokenCollateralAddress)
    {
        _burnPkr(amountDscToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @dev Redeem collateral (not yet implemented).
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        nonZeroAmount(amountCollateral)
        nonReentrant
    // isAllowedCollateralToken(tokenCollateralAddress)
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert PKRSEngine__TransferFailed();
        }
    }

    /**
     * @dev Mint PKRS tokens (not yet implemented).
     */
    function mintPKRS(uint256 _amountPKRSToMint) public nonZeroAmount(_amountPKRSToMint) {
        s_PKRSMinted[msg.sender] += _amountPKRSToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_pkrsToken.mint(msg.sender, _amountPKRSToMint);
        if (!minted) {
            revert PKRSEngine__MintFailed();
        }
    }

    /**
     * @dev Deposit collateral and mint PKRS tokens (not yet implemented).
     */
    function depositCollateralAndMintPKRS(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintPKRS(amountDscToMint);
    }

    /**
     * @dev Burn PKRS tokens (not yet implemented).
     */
    function burnPKRS(uint256 amount) external nonZeroAmount(amount) {
        _burnPkr(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit...
    }

    function _burnPkr(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_PKRSMinted[onBehalfOf] -= amountDscToBurn;

        bool success = i_pkrsToken.transferFrom(dscFrom, address(this), amountDscToBurn);
        // This conditional is hypothetically unreachable
        if (!success) {
            revert PKRSEngine__TransferFailed();
        }
        i_pkrsToken.burn(amountDscToBurn);
    }

    /**
     * @dev Liquidate positions (not yet implemented).
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        nonZeroAmount(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert PKRSEngine__HealthFactorOK();
        }
        // If covering 100 DSC, we need to $100 of collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // And give them a 10% bonus
        // So we are giving the liquidator $110 of WETH for 100 DSC
        // We should implement a feature to liquidate in the event the protocol is insolvent
        // And sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        // Burn DSC equal to debtToCover
        // Figure out how much collateral to recover based on how much burnt
        _redeemCollateral(collateral, tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnPkr(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        // This conditional should never hit, but just in case
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert PKRSEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    //////////////////////////////////////
    /// View Functions ///
    //////////////////////////////////////

    /**
     * @dev Get the health factor of a user's position (not yet implemented).
     */
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    //////////////////////////////////////
    ///  Internal & Private Functions  ///
    //////////////////////////////////////

    function getAccountCollaterValue(address _user) public view returns (uint256 _collateralValueInPKRS) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address _token = s_collateralTokens[i];
            uint256 _amount = s_collateralDeposited[_user][_token];
            _collateralValueInPKRS = _getPKRValue(_token, _amount);
        }
    }

    function _getPKRValue(address _token, uint256 _amount) internal view returns (uint256) {
        AggregatorV3Interface _priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (, int256 _price,,,) = _priceFeed.latestRoundData();
        return ((uint256(_price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION;
    }

    function _getAccountInformation(address _user)
        private
        view
        returns (uint256 _totalPKRSMinted, uint256 _collateralValueInPKRS)
    {
        _totalPKRSMinted = s_PKRSMinted[_user];
        _collateralValueInPKRS = getAccountCollaterValue(_user);
    }

    function getPKRValue(
        address token,
        uint256 amount // in WEI
    )
        external
        view
        returns (uint256)
    {
        return _getPKRValue(token, amount);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function _healthFactor(address _user) private view returns (uint256) {
        (uint256 _totalPKRSMinted, uint256 _collateralValueInPKRS) = _getAccountInformation(_user);
        uint256 _collateralAdjustedForThreshHold = (_collateralValueInPKRS * LIQUIDATION_THRESHOLD) / 100;
        return (_collateralAdjustedForThreshHold * PRECISION / _totalPKRSMinted);
    }

    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 _userHealtFactor = _healthFactor(_user);
        if (_userHealtFactor < MIN_HEALTH_FACTOR) {
            revert PKRSEngine__BreaksHealthFactor(_userHealtFactor);
        }
    }

    function getTokenAmountFromUsd(address _token, uint256 _usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface _priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (, int256 price,,,) = _priceFeed.latestRoundData();
        // $100e18 USD Debt
        // 1 ETH = 2000 USD
        // The returned value from Chainlink will be 2000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        return ((_usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }
}
