# Foundry Framework - Comprehensive Tutorial

## Table of Contents
- [Foundry Framework - Comprehensive Tutorial](#foundry-framework---comprehensive-tutorial)
  - [Table of Contents](#table-of-contents)
  - [What is Foundry?](#what-is-foundry)
    - [Why Foundry?](#why-foundry)
    - [Core Components](#core-components)
  - [Installation \& Setup](#installation--setup)
    - [Install Foundry](#install-foundry)
    - [Create New Project](#create-new-project)
    - [Install Dependencies](#install-dependencies)
    - [Configuration (foundry.toml)](#configuration-foundrytoml)
  - [Project Structure](#project-structure)
    - [Import Remappings](#import-remappings)
  - [Writing Contracts](#writing-contracts)
    - [Example: Simple Token](#example-simple-token)
    - [Build Contracts](#build-contracts)
  - [Testing Basics](#testing-basics)
    - [Test Structure Token Test](#test-structure-token-test)
    - [Running Tests](#running-tests)
    - [Verbosity Levels](#verbosity-levels)
  - [Advanced Testing](#advanced-testing)
    - [Example: SimpleDEX](#example-simpledex)
    - [Example: DEX Testing](#example-dex-testing)

---

## What is Foundry?

**Foundry** is a blazing fast, portable, and modular toolkit for Ethereum application development written in Rust.

### Why Foundry?

**vs Hardhat:**
```
Foundry:
✅ 10-100x faster testing
✅ Write tests in Solidity (not JavaScript)
✅ Built-in fuzzing
✅ Gas reports built-in
✅ No node_modules (lightweight)

Hardhat:
✅ Mature ecosystem
✅ JavaScript/TypeScript (familiar to web devs)
✅ More plugins
```

### Core Components

```
forge:   Build, test, deploy contracts
cast:    Interact with contracts (like CLI)
anvil:   Local Ethereum node
chisel:  Solidity REPL
```

---

## Installation & Setup

### Install Foundry

```bash
# Install foundryup
curl -L https://foundry.paradigm.xyz | bash

# Install Foundry
foundryup

# Verify installation
forge --version
cast --version
anvil --version
```

### Create New Project

```bash
# Create project
forge init my-project
cd my-project

# Project structure created:
# ├── src/           # Smart contracts
# ├── test/          # Test files
# ├── script/        # Deployment scripts
# ├── lib/           # Dependencies
# └── foundry.toml   # Configuration
```

### Install Dependencies

```bash
# Install OpenZeppelin
forge install OpenZeppelin/openzeppelin-contracts

# Install with specific version
forge install OpenZeppelin/openzeppelin-contracts@v4.9.0

# Install Solmate (gas-optimized contracts)
forge install transmissions11/solmate

# Update dependencies
forge update
```

### Configuration (foundry.toml)

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.20"
optimizer = true
optimizer_runs = 200
via_ir = false

# Formatting
line_length = 100
tab_width = 4
bracket_spacing = true

# Testing
verbosity = 3
fuzz_runs = 256
fuzz_max_test_rejects = 65536

# RPC endpoints
[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
goerli = "${GOERLI_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"

# Etherscan API keys
[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
```

---

## Project Structure

### Import Remappings

```txt
# remappings.txt
@openzeppelin/=lib/openzeppelin-contracts/
@solmate/=lib/solmate/src/
forge-std/=lib/forge-std/src/
```

**In contracts:**
```solidity
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@solmate/tokens/ERC20.sol";
import "forge-std/Test.sol";
```

---

## Writing Contracts

### Example: [Simple Token](./src/MyToken.sol)

### Build Contracts

```bash
# Compile contracts
forge build

# Build with specific compiler version
forge build --use 0.8.20

# Show detailed output
forge build --sizes

# Clean and rebuild
forge clean && forge build
```

---

## Testing Basics

### Test Structure [Token Test](./test/Mytoken.t.sol)

### Running Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/MyToken.t.sol

# Run specific test function
forge test --match-test test_Mint

# Show detailed output
forge test -vvvv

# Show gas report
forge test --gas-report

# Run with coverage
forge coverage
```

### Verbosity Levels

```
-v:    Show test results
-vv:   Show logs
-vvv:  Show stack traces for failing tests
-vvvv: Show stack traces for all tests + setup
-vvvvv: Show everything (including internal calls)
```

---

## Advanced Testing

### Example: [SimpleDEX](./src/SimpleDEX.sol)

### Example: DEX Testing