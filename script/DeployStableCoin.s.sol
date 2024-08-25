// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {PKRSEngine} from "src/PKRSEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployStableCoin is Script {

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns(DecentralizedStableCoin, PKRSEngine, HelperConfig) {

        HelperConfig helperConfig = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        // Deploy the DecentralizedStableCoin contract
        DecentralizedStableCoin stableCoin = new DecentralizedStableCoin();
        PKRSEngine engine = new PKRSEngine(tokenAddresses, priceFeedAddresses, address(stableCoin));
        stableCoin.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (stableCoin, engine, helperConfig);
    }
}
