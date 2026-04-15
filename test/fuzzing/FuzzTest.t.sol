// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../../src/MyToken.sol";

contract FuzzTest is Test {
    MyToken public token;

    function setUp() public {
        token = new MyToken();
    }

    // Foundry will call this with random values
    function testFuzzMint(address to, uint256 amount) public {
        // Bound inputs to valid ranges
        amount = bound(amount, 0, token.MAX_SUPPLY());
        vm.assume(to != address(0));

        token.mint(to, amount);

        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzzTransfer(
        address from,
        address to,
        uint256 mintAmount,
        uint256 transferAmount
    ) public {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);

        mintAmount = bound(mintAmount, 0, token.MAX_SUPPLY());
        transferAmount = bound(transferAmount, 0, mintAmount);

        // Setup
        token.mint(from, mintAmount);

        // Transfer
        vm.prank(from);
        token.transfer(to, transferAmount);

        // Assertions
        assertEq(token.balanceOf(from), mintAmount - transferAmount);
        assertEq(token.balanceOf(to), transferAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    function testFuzzBurnDoesNotOverflow(uint256 amount) public {
        amount = bound(amount, 0, token.MAX_SUPPLY());

        address user = makeAddr("user");
        token.mint(user, amount);

        vm.prank(user);
        token.burn(amount);

        assertEq(token.balanceOf(user), 0);
    }
}