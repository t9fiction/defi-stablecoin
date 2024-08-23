// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @author DSC Engine
 */
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PKRSEngine is ReentrancyGuard {
    error PKRSEngine__ZeroAmount();
    error PKRSEngine__InvalidCollateralToken();
    error PKRSEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    DecentralizedStableCoin private immutable pkrsToken;

    modifier zeroAmount(uint256 _amount) {
        if (_amount == 0) {
            revert PKRSEngine__ZeroAmount();
        }
        _;
    }

    modifier isAllowedCollateralToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert PKRSEngine__InvalidCollateralToken();
        }
        _;
    }

    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address _PKRSAddress) {
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert PKRSEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeeds[_tokenAddresses[i]] = s_priceFeeds[_priceFeedAddresses[i]];
        }
        pkrsToken = DecentralizedStableCoin(_PKRSAddress);
    }

    function depositCollateralAndMintPKRS() external {}

    function depositCollateral(address _tokenCollateralAddress, uint256 _amountCollateral)
        external
        zeroAmount(_amountCollateral)
        isAllowedCollateralToken(_tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _amountCollateral;
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _amountCollateral);
    }

    function redeemCollateralForPKRS() external {}

    function redeemCollateral() external {}

    function mintPKRS() external {}

    function burnPKRS() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
