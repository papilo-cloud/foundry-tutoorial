// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SimpleDEX} from "../src/SimpleDEX.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}


contract SimpleDEXTest is Test {
    SimpleDEX public dex;
    MockToken public tokenA;
    MockToken public tokenB;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        // Deploy tokens
        tokenA = new MockToken("Token A", "TKA");
        tokenB = new MockToken("Token B", "TKB");

        // Deploy dex
        dex = new SimpleDEX(address(tokenA), address(tokenB));

        // Give tokens to users
        tokenA.mint(alice, 10_000 * 10**18);
        tokenB.mint(alice, 10_000 * 10**18);
        tokenA.mint(bob, 10_000 * 10**18);
        tokenB.mint(bob, 10_000 * 10**18);
        tokenA.mint(attacker, 10_000 * 10**18);
        tokenB.mint(attacker, 10_000 * 10**18);

        // vm.label(alice, "Alice");
        // vm.label(bob, "Bob");
        // vm.label(attacker, "Attacker");
    }

    // Helper function
    function setupLiquidity() public returns (uint256, uint256, uint256) {
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 2000 * 10**18;

        tokenA.approve(address(dex), amountA);
        tokenB.approve(address(dex), amountB);

        uint256 lpTokens = dex.addLiquidity(amountA, amountB, 0, block.timestamp + 1000);

        return (amountA, amountB, lpTokens);
    }

    // ========== TEST: BASIC FUNCTIONALITY ==========

    function test_AddLiquidityFirst() public {
        vm.startPrank(alice);

        (uint256 amountA, uint256 amountB, uint256 lpTokens) = setupLiquidity();

        console.log(lpTokens);

        // First depositor gets sqrt(1000 * 2000) - MINIMUM_LIQUIDITY
        uint256 expected = dex.sqrt(amountA * amountB) - dex.MINIMUM_LIQUIDITY();
        
        assertEq(lpTokens, expected);
        assertEq(dex.liquidityBalances(alice), expected);

        vm.stopPrank();
    }

    function test_AddLiquiditySecond() public {
        // Alice adds first
        vm.startPrank(alice);
        setupLiquidity();
        vm.stopPrank();

        // Bob adds second
        vm.startPrank(bob);
        (,, uint256 lpTokens) = setupLiquidity();
        vm.stopPrank();

        // Should get proportional share
        assertTrue(lpTokens > 0);
        assertEq(dex.liquidityBalances(bob), lpTokens);
    }

    function test_RemoveLiquidity() public {
        vm.startPrank(alice);
        (,, uint256 lpTokens) = setupLiquidity();

        // Remove half
        uint256 halfLp = lpTokens / 2;
        (uint256 amountA, uint256 amountB) = dex.removeLiquidity(halfLp, 0, 0, block.timestamp + 1000);

        console.log(lpTokens);
        console.log(amountA);

        // Should get approximately half back
        assertApproxEqRel(amountA, 500e18, 0.01e18); // 1% tolerance
        assertApproxEqRel(amountB, 1000e18, 0.01e18);
        vm.stopPrank();
    }

    function test_Swap() public {
        vm.startPrank(alice);
        setupLiquidity();
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(dex), 100e18);

        uint256 amountOut = dex.swap(100e18, address(tokenA), 0, block.timestamp);

        console.log(amountOut/1e18);

        assertTrue(amountOut > 0);
        assertTrue(amountOut < 200e18); // Should get less than 2:1 

        vm.stopPrank();
    }

    // ========== TEST: TWAP ORACLE ==========

    function test_TWAPUpdates() public {
        vm.startPrank(alice);
        setupLiquidity();
        vm.stopPrank();

        // Get initial timestamp
        (,, uint32 timestamp1) = dex.getReserves();

        // Wait some time
        vm.warp(block.timestamp + 1);

        // Make a swap to trigger update
        vm.startPrank(bob);
        tokenA.approve(address(dex), 100e18);
        dex.swap(100e18, address(tokenA), 0, block.timestamp + 1000);
        vm.stopPrank();

        // check timestamp updated
        (,, uint32 timestamp2) = dex.getReserves();
        assertTrue(timestamp2 > timestamp1);
    }

    // ========== TEST: CONSTANT PRODUCT VERIFICATION ==========
    
    function test_ConstantProductIncreases() public {
        // Setup liquidity
        vm.startPrank(alice);
        setupLiquidity();
        vm.stopPrank();
        
        (uint256 reserveA1, uint256 reserveB1,) = dex.getReserves();
        uint256 k1 = reserveA1 * reserveB1;
        
        // Do a swap
        vm.startPrank(bob);
        tokenA.approve(address(dex), 100e18);
        dex.swap(100e18, address(tokenA), 0, block.timestamp + 1000);
        vm.stopPrank();
        
        (uint256 reserveA2, uint256 reserveB2,) = dex.getReserves();
        uint256 k2 = reserveA2 * reserveB2;

        console.log(k1);
        console.log(k2);
        
        // K should increase due to fees
        assertTrue(k2 >= k1);
    }

    // ========== TEST: PRECISION LOSS PROTECTION ==========
    
    // function test_NoPrecisionLossOnSmallAmounts() public {
    //     // Setup liquidity
    //     vm.startPrank(alice);
    //     setupLiquidity();
    //     vm.stopPrank();
        
    //     // Try to swap very small amount
    //     vm.startPrank(bob);
    //     tokenA.approve(address(dex), 1);
        
    //     uint256 amountOut = dex.swap(1, address(tokenA), 0, block.timestamp + 1000);
        
    //     // Should still get something (not rounded to zero)
    //     // Note: might be 0 due to fees, but shouldn't revert
    //     assertTrue(amountOut >= 0);
        
    //     vm.stopPrank();
    // }
    
    // ========== TEST: HELPER FUNCTIONS ==========
    
    function test_GetAmountOut() public {
        uint256 amountOut = dex.getAmountOut(100e18, 1000e18, 2000e18);
        assertTrue(amountOut > 0);
        assertTrue(amountOut < 200e18); // Should be less than 2:1 ratio
    }
    
    function test_GetSpotPrice() public {
        vm.startPrank(alice);
        setupLiquidity();
        vm.stopPrank();
        
        uint256 priceA = dex.getSpotPrice(address(tokenA));
        uint256 priceB = dex.getSpotPrice(address(tokenB));
        
        // Price of A should be approximately 2 (2000/1000)
        assertApproxEqRel(priceA, 2e18, 0.01e18);
        // Price of B should be approximately 0.5 (1000/2000)
        assertApproxEqRel(priceB, 0.5e18, 0.01e18);
    }
    
    function test_GetReserves() public {
        vm.startPrank(alice);
        setupLiquidity();
        vm.stopPrank();
        
        (uint256 resA, uint256 resB, uint32 timestamp) = dex.getReserves();
        
        assertEq(resA, 1000e18);
        assertEq(resB, 2000e18);
        assertEq(timestamp, uint32(block.timestamp));
    }
}

