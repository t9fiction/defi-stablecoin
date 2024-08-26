// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin stableCoin;

    address owner = address(0x1);
    address recipient = address(0x2);

    function setUp() public {
        stableCoin = new DecentralizedStableCoin();
        stableCoin.transferOwnership(owner);
    }

    function testMint() public {
        vm.prank(owner);
        uint256 amount = 1000 * 1e18;
        bool success = stableCoin.mint(recipient, amount);
        assertTrue(success);
        assertEq(stableCoin.balanceOf(recipient), amount);
    }

    function testMintFailsForNonOwner() public {
        uint256 amount = 1000 * 1e18;
        vm.expectRevert("Ownable: caller is not the owner");
        stableCoin.mint(recipient, amount);
    }

    function testBurn() public {
        vm.startPrank(owner);
        uint256 amount = 1000 * 1e18;
        stableCoin.mint(owner, amount);
        stableCoin.burn(amount);
        assertEq(stableCoin.balanceOf(owner), 0);
        vm.stopPrank();
    }

    function testBurnFailsForNonOwner() public {
        vm.prank(owner);
        uint256 amount = 1000 * 1e18;
        stableCoin.mint(owner, amount);

        vm.prank(recipient);
        vm.expectRevert("Ownable: caller is not the owner");
        stableCoin.burn(amount);
    }
}
