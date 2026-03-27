// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleDEX.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    function test_AddLiquidityFirst() public {
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 2000 * 10**18;

        vm.startPrank(alice);
        tokenA.approve(address(dex), amountA);
        tokenB.approve(address(dex), amountB);

        uint256 lpTokens = dex.addLiquidity(amountA, amountB, 0, block.timestamp + 1000);

        // First depositor gets sqrt(1000 * 2000) - MINIMUM_LIQUIDITY
        uint256 expected = dex.sqrt(amountA * amountB) - dex.MINIMUM_LIQUIDITY();
        
        assertEq(lpTokens, expected);
        assertEq(dex.liquidityBalances(alice), expected);

        vm.stopPrank();
    }

    function test_AddLiquiditySecond() public {
        // Alice adds first
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 2000 * 10**18;

        vm.startPrank(alice);
        tokenA.approve(address(dex), amountA);
        tokenB.approve(address(dex), amountB);

        dex.addLiquidity(amountA, amountB, 0, block.timestamp + 1000);
        vm.stopPrank();

        // Bob adds second
        vm.startPrank(bob);
        tokenA.approve(address(dex), amountA);
        tokenB.approve(address(dex), amountB);

        uint256 lpTokens = dex.addLiquidity(amountA, amountB, 0, block.timestamp + 1000);
        vm.stopPrank();

        // Should get proportional share
        assertTrue(lpTokens > 0);
        assertEq(dex.liquidityBalances(bob), lpTokens);
    }
}