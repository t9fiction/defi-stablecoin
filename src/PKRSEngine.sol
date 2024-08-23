// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

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

    //////////////////////////
    /// State Variables ///
    //////////////////////////

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountPKRSMinted) private s_PKRSMinted;
    address[] private s_collateralTokens;

    ///////////////////////
    /// Events ///
    ///////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount); // Event emitted when collateral is deposited

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
    constructor(
        address[] memory _tokenAddresses,
        address[] memory _priceFeedAddresses,
        address _PKRSAddress
    ) {
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
     * @dev Deposit collateral and mint PKRS tokens (not yet implemented).
     */
    function depositCollateralAndMintPKRS() external {
        // Implementation to be added
    }

    /**
     * @dev Deposit collateral for a specific token.
     * @param _tokenCollateralAddress The address of the collateral token.
     * @param _amountCollateral The amount of collateral to deposit.
     */
    function depositCollateral(
        address _tokenCollateralAddress,
        uint256 _amountCollateral
    )
        external
        nonZeroAmount(_amountCollateral)
        isAllowedCollateralToken(_tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _amountCollateral;
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _amountCollateral);
        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender,address(this),_amountCollateral);
        if(!success){
            revert PKRSEngine__TransferFailed();
        }
    }

    /**
     * @dev Redeem collateral for PKRS tokens (not yet implemented).
     */
    function redeemCollateralForPKRS() external {
        // Implementation to be added
    }

    /**
     * @dev Redeem collateral (not yet implemented).
     */
    function redeemCollateral() external {
        // Implementation to be added
    }

    /**
     * @dev Mint PKRS tokens (not yet implemented).
     */
    function mintPKRS(uint256 _amountPKRSToMint) external nonZeroAmount(_amountPKRSToMint) {
        s_PKRSMinted[msg.sender] += _amountPKRSToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_pkrsToken.mint(msg.sender, _amountPKRSToMint);
        if(!minted){
            revert PKRSEngine__MintFailed();
        }
    }

    /**
     * @dev Burn PKRS tokens (not yet implemented).
     */
    function burnPKRS() external {
        // Implementation to be added
    }

    /**
     * @dev Liquidate positions (not yet implemented).
     */
    function liquidate() external {
        // Implementation to be added
    }

    //////////////////////////////////////
    /// View Functions ///
    //////////////////////////////////////

    /**
     * @dev Get the health factor of a user's position (not yet implemented).
     */
    function getHealthFactor() external view {
        // Implementation to be added
    }

    //////////////////////////////////////
    ///  Internal & Private Functions  ///
    //////////////////////////////////////

    function getAccountCollaterValue(address _user) public view returns(uint256 _collateralValueInPKRS){
        for (uint i = 0; i < s_collateralTokens.length; i++) {
            address _token = s_collateralTokens[i];
            uint256 _amount = s_collateralDeposited[_user][_token];
            _collateralValueInPKRS = getPKRValue(_token, _amount);
        }
    }

    function getPKRValue(address _token, uint256 _amount) public view returns(uint256){
        AggregatorV3Interface _priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (,int256 _price,,,) = _priceFeed.latestRoundData();
        return ((uint256(_price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION ;
    }

    function _getAccountInformation(address _user) private view returns(uint256 _totalPKRSMinted, uint256 _collateralValueInPKRS){
        _totalPKRSMinted = s_PKRSMinted[_user];
        _collateralValueInPKRS = getAccountCollaterValue(_user);
    }

    function _healthFactor(address _user) private view returns(uint256){
        (uint256 _totalPKRSMinted, uint256 _collateralValueInPKRS) = _getAccountInformation(_user);
        uint256 _collateralAdjustedForThreshHold = (_collateralValueInPKRS * LIQUIDATION_THRESHOLD) / 100;
        return (_collateralAdjustedForThreshHold * PRECISION / _totalPKRSMinted);
    }

    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 _userHealtFactor = _healthFactor(_user);
        if(_userHealtFactor < MIN_HEALTH_FACTOR){
            revert PKRSEngine__BreaksHealthFactor(_userHealtFactor);
        }
    }

}
