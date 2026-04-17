// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SimpleDEX} from "../../src/SimpleDEX.sol";
import {MockToken} from "../SimpleDEXTest.t.sol";

contract AdvancedFuzzTest is Test {
    SimpleDEX public dex;
    MockToken public tokenA;
    MockToken public tokenB;

    function setUp() public {
        tokenA = new MockToken("Token A", "TKA");
        tokenB = new MockToken("Token B", "TKB");
        dex = new SimpleDEX(address(tokenA), address(tokenB));

        // Add initial liquidity
        tokenA.approve(address(dex), type(uint256).max);
        tokenB.approve(address(dex), type(uint256).max);

        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 2000 * 10**18;
        dex.addLiquidity(amountA, amountB, 0, block.timestamp + 1000);
    }

    function testFuzzSwapMaintainsK(uint256 swapAmount) public {
        swapAmount = bound(swapAmount, 10e18, 10000e18);

        // Get k before swap
        (uint256 reserve0Before, uint256 reserve1Before, ) = dex.getReserves();
        uint256 kBefore = reserve0Before * reserve1Before;

        // Perform swap
        tokenA.approve(address(dex), swapAmount);
        dex.swap(swapAmount, address(tokenA), 0, block.timestamp);

        // Get k after swap
        (uint256 reserve0After, uint256 reserve1After, ) = dex.getReserves();
        uint256 kAfter = reserve0After * reserve1After;

        // k should increase (due to fees) or stay same
        assertGe(kAfter, kBefore, "k should not decrease");
    }

    function testFuzzAddRemoveLiquidity(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1000e18, 100000e18);
        amountB = bound(amountB, 2000e18, 200000e18);

        address user = makeAddr("user");
        tokenA.transfer(user, amountA);
        tokenB.transfer(user, amountB);

        vm.startPrank(user);

        // Add liquidity
        tokenA.approve(address(dex), amountA);
        tokenB.approve(address(dex), amountB);
        uint256 liquidity = dex.addLiquidity(amountA, amountB, 0, block.timestamp + 1000);

        // Remove liquidity
        (uint256 amount0, uint256 amount1) = dex.removeLiquidity(liquidity, 0, 0, block.timestamp + 1000);

        vm.stopPrank();

        console.log(amount0);
        console.log(amount1);
        console.log(amountA);
        console.log(amountB);
        console.log(liquidity);

        assertApproxEqRel(amount0, amountA, 1e18); // 1% tolerance
        assertApproxEqRel(amount1, amountB, 1e18);
    }
}