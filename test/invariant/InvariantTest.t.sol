// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../../src/MyToken.sol";

contract InvariantTest is Test{
    MyToken public token;
    TokenHandler public handler;

    function setUp() public {
        token = new MyToken();
        handler = new TokenHandler(token);

        // Tell Foundry to call functions on handler
        targetContract(address(handler));
    }

    // This invariant is checked after every handler call
    function invariant_totalSupplyEqualsBalances() public {
        uint256 totalSupply = token.totalSupply();
        uint256 sumBalances = handler.sumBalances();

        assertEq(totalSupply, sumBalances,  "Invariant broken");
    }

    function invariant_totalSupplyNeverExceedsMax() public {
        assertLe(token.totalSupply(), token.MAX_SUPPLY(), "Supply exceeds max");
    }
}


// Handler to generate random sequences of calls
contract TokenHandler is Test {
    MyToken public token;
    address[] public actors;
    uint256 public constant NUM_ACTOR = 10;

    constructor(MyToken _token) {
        token = _token;

        // Create actors
        for (uint256 i = 0; i < NUM_ACTOR; i++) {
            actors.push(makeAddr(string(abi.encodePacked("actor", i))));
        }
    }

    function mint(uint256 actorSeed, uint256 amount) public {
        address actor = actors[actorSeed % NUM_ACTOR];
        amount = bound(amount, 0, token.MAX_SUPPLY() - token.totalSupply());

        token.mint(actor, amount);
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public {
        address from = actors[fromSeed % NUM_ACTOR];
        address to = actors[toSeed % NUM_ACTOR];

        uint256 balance = token.balanceOf(from);
        if (balance == 0) return;

        amount = bound(amount, 0, balance);

        vm.prank(from);
        token.transfer(to, amount);
    }

    function burn(uint256 actorSeed, uint256 amount) public {
        address actor = actors[actorSeed % NUM_ACTOR];
        uint256 balance = token.balanceOf(actor);

        if (balance == 0) return;

        amount = bound(amount, 0, balance);

        vm.prank(actor);
        token.burn(amount);
    }

    function sumBalances() external view returns (uint256 sum) {
        for (uint256 i = 0; i < NUM_ACTOR; i++) {
            sum += token.balanceOf(actors[i]);
        }
    }
}