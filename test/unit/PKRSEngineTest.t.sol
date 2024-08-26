// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployStableCoin} from "script/DeployStableCoin.s.sol";
import {PKRSEngine} from "src/PKRSEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract PKRSEngineTest is Test {
    DeployStableCoin deployer;
    PKRSEngine pkrEngine;
    DecentralizedStableCoin pkrsToken;
    HelperConfig config;
    address ethUsdpriceFeedAddress;
    address btcUsdPriceFeedAddress;
    address weth;
    address public USER = makeAddr("user"); // Test user address
    uint256 public constant COLLATERALAMOUNT = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployStableCoin();
        (pkrsToken, pkrEngine, config) = deployer.run();
        (ethUsdpriceFeedAddress, btcUsdPriceFeedAddress, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    // function testConstructorRevertsWithMismatchedArrayLengths() public {
    //     address;
    //     address; // Deliberately mismatched

    //     vm.expectRevert(PKRSEngine.PKRSEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength.selector);
    //     new PKRSEngine(tokenAddresses, priceFeedAddresses, address(pkrsToken));
    // }


    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdpriceFeedAddress);
        priceFeedAddresses.push(btcUsdPriceFeedAddress);

        vm.expectRevert(PKRSEngine.PKRSEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength.selector);
        new PKRSEngine(tokenAddresses, priceFeedAddresses, address(pkrsToken));
    }

    function testGetTokenAmountFromUsd() public {
        // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
        uint256 expectedWeth = 0.05 ether;
        uint256 amountWeth = pkrEngine.getTokenAmountFromUsd(weth, 100 ether);
        assertEq(amountWeth, expectedWeth);
    }

    function testRevertsIfCollateralZero() public {

        // Mint collateral tokens to user
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(pkrEngine), COLLATERALAMOUNT);
        // ERC20Mock(weth).mint(USER, COLLATERALAMOUNT);

        vm.expectRevert(PKRSEngine.PKRSEngine__ZeroAmount.selector);
        pkrEngine.depositCollateral(weth, 0);

        vm.stopPrank();
    }

    function testDepositCollateralRevertsWithInvalidToken() public {
        address invalidToken = address(0x1111);
        vm.expectRevert(PKRSEngine.PKRSEngine__InvalidCollateralToken.selector);
        vm.prank(USER);
        pkrEngine.depositCollateral(invalidToken, 1000 * 1e18);
    }

    // function testMintPKRS() public {
    //     uint256 amountToMint = 100 * 1e18;

    //     // First, deposit enough collateral
    //     testDepositCollateral();

    //     vm.prank(user);
    //     pkrEngine.mintPKRS(amountToMint);

    //     uint256 mintedAmount = pkrEngine.getPKRSMinted(user);
    //     assertEq(mintedAmount, amountToMint);
    // }

    function testMintPKRSRevertsWithZeroAmount() public {
        vm.expectRevert(PKRSEngine.PKRSEngine__ZeroAmount.selector);
        vm.prank(USER);
        pkrEngine.mintPKRS(0);
    }

    // function testMintPKRSRevertsWhenHealthFactorIsBroken() public {
    //     uint256 amountToMint = 1000 * 1e18; // Large enough to break health factor

    //     // First, deposit a small amount of collateral
    //     testDepositCollateral();

    //     vm.expectRevert(PKRSEngine.PKRSEngine__BreaksHealthFactor.selector);
    //     vm.prank(user);
    //     pkrEngine.mintPKRS(amountToMint);
    // }

    // More tests can be added for other functions and edge cases
    function testGetPKRSValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedPKRS = 30000e18;
        uint256 actualPKRS = pkrEngine.getPKRValue(weth, ethAmount);
        assertEq(expectedPKRS,actualPKRS);
    }
}
