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

contract PKRSEngine is ReentrancyGuard {

    ////////////////////////
    /// Custom Errors ///
    ////////////////////////

    error PKRSEngine__ZeroAmount();
    error PKRSEngine__InvalidCollateralToken();
    error PKRSEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();

    //////////////////////////
    /// State Variables ///
    //////////////////////////

    mapping(address token => address priceFeed) private s_priceFeeds; // Mapping of token addresses to price feed addresses
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // User's deposited collateral per token

    ///////////////////////
    /// Events ///
    ///////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount); // Event emitted when collateral is deposited

    ////////////////////////////
    /// Immutable Variables ///
    ////////////////////////////

    DecentralizedStableCoin private immutable pkrsToken; // The PKRS token (Decentralized StableCoin)

    //////////////////////
    /// Modifiers ///
    //////////////////////

    modifier zeroAmount(uint256 _amount) {
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
        }
        // Set the PKRS token address
        pkrsToken = DecentralizedStableCoin(_PKRSAddress);
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
        zeroAmount(_amountCollateral)
        isAllowedCollateralToken(_tokenCollateralAddress)
        nonReentrant
    {
        // Update the user's collateral balance for the specified token
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _amountCollateral;

        // Emit the CollateralDeposited event
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _amountCollateral);
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
    function mintPKRS() external {
        // Implementation to be added
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
}
