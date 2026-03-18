// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
    address public owner;
    address public alice;
    address public bob;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new MyToken();
    }

    function test_Mint() public {
        uint256 amount = 1000 * 1e18;
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_CannotMintAboveMax() public {
        uint256 amount = token.MAX_SUPPLY() + 1;

        vm.expectRevert("Exceeds max supply");
        token.mint(alice, amount);
    }

    function test_OnlyOwnerCanMint() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(bob, 10000);
    }

    function test_Burn() public {
        uint256 amount = 1000 * 1e18;
        token.mint(bob, amount);

        vm.prank(bob);
        token.burn(500 * 1e18);

        assertEq(token.balanceOf(bob), 500 * 1e18);
    }
}