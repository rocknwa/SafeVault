# SafeVault

![Solidity](https://img.shields.io/badge/Solidity-0.8.26-black) ![Tests](https://img.shields.io/badge/Tests-100%25%20Passed-brightgreen)

SafeVault is a secure Ethereum smart contract designed for managing user deposits with a lock period and a whitelisting mechanism. It allows whitelisted users to deposit Ether, lock it for a minimum of 7 days, and withdraw it after the lock period expires. The contract incorporates security features like reentrancy protection and extensive testing to ensure reliability.

## Table of Contents
- [SafeVault](#safevault)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Features](#features)
  - [Contract Details](#contract-details)
    - [Additional Contracts](#additional-contracts)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Steps](#steps)
  - [Usage](#usage)
  - [Testing](#testing)
    - [Test Breakdown](#test-breakdown)
    - [Running Tests](#running-tests)
    - [Coverage Results](#coverage-results)
  - [Security](#security)
    - [Known Considerations](#known-considerations)
  - [Contributing](#contributing)
  - [Author](#author)

## Overview
SafeVault is a decentralized vault contract that enables secure Ether storage with time-locked withdrawals. Only whitelisted users (up to a maximum of 100) can deposit funds, and withdrawals are restricted until a 7-day lock period has passed. The contract is built with Solidity 0.8.26, uses OpenZeppelin's `ReentrancyGuard` for security, and has been thoroughly tested using Foundry for unit, fuzz, and invariant testing.

## Features
- **Whitelisting**: Limits access to a maximum of 100 users, ensuring controlled participation.
- **Minimum Deposit**: Enforces a minimum deposit of 1 Ether to prevent spam transactions.
- **Time-Locked Withdrawals**: Funds are locked for 7 days after deposit, with an option to extend the lock period.
- **Reentrancy Protection**: Uses OpenZeppelin's `ReentrancyGuard` to prevent reentrancy attacks.
- **Event Emissions**: Emits events for whitelisting, deposits, withdrawals, and lock time extensions for transparency.
- **Comprehensive Testing**: Includes unit tests, fuzz tests, and invariant tests with 100% code coverage.

## Contract Details
The `Vault.sol` contract is the core of the SafeVault project. Key components include:

- **User Struct**: Tracks each user's balance, last deposit timestamp, and whitelist status.
- **Key Functions**:
  - `whitelistUser()`: Adds a user to the whitelist (max 100 users).
  - `deposit()`: Allows whitelisted users to deposit at least 1 Ether.
  - `withdraw(uint256 amount)`: Permits withdrawals after the 7-day lock period.
  - `extendLockTime(uint256 additionalDays)`: Extends the lock period for a user's funds.
  - `getWithdrawalInfo(address user)`: Returns a user's balance and days remaining until withdrawal.
- **Security Features**:
  - Reentrancy protection via `ReentrancyGuard`.
  - Custom errors for clear failure reasons (e.g., `NotWhitelisted`, `FundsLocked`, `DepositTooSmall`).
  - Ether transfer validation to prevent failed withdrawals.
- **Constants**:
  - `MAX_USERS`: 100
  - `MIN_DEPOSIT`: 1 Ether
  - `LOCK_PERIOD`: 7 days
  - `SECONDS_PER_DAY`: 86,400

### Additional Contracts
- **ReentrantAttacker.sol**: A test contract to simulate reentrancy attacks, confirming the Vault's protection.
- **ReceiverReverts.sol**: A test contract that reverts on Ether receipt, used to test failed withdrawal scenarios.

## Installation
To set up and interact with the SafeVault project locally, follow these steps:

### Prerequisites
- [Foundry](https://book.getfoundry.sh/) (Forge, Cast, Anvil)
 
- [Git](https://git-scm.com/)

### Steps
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/rocknwa/SafeVault.git 
   cd SafeVault
   ```

2. **Install Foundry** (if not already installed):
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

3. **Install Dependencies**:
   The project uses OpenZeppelin contracts. Install them via Forge:
   ```bash
   forge install openzeppelin/openzeppelin-contracts@v5.0.2
   ```

4. **Compile the Contracts**:
   ```bash
   forge build
   ```

5. **Deploy the Contract**:
   Use the provided `DeployVault.s.sol` script to deploy the Vault contract:
   ```bash
   forge script script/DeployVault.s.sol --rpc-url <your-rpc-url> --private-key <your-private-key> --broadcast
   ```

## Usage
1. **Whitelist a User**:
   - Call `whitelistUser()` to add your address to the whitelist.
   - Ensure the whitelist count is below `MAX_USERS` (100).

2. **Deposit Funds**:
   - Call `deposit()` with at least 1 Ether (`MIN_DEPOSIT`).
   - Example:
     ```solidity
     vault.deposit{value: 1 ether}();
     ```

3. **Extend Lock Period** (Optional):
   - Call `extendLockTime(uint256 additionalDays)` to extend the lock period for your funds.
   - Example:
     ```solidity
     vault.extendLockTime(3); // Extends lock by 3 days
     ```

4. **Check Withdrawal Info**:
   - Call `getWithdrawalInfo(address user)` to view your balance and days until withdrawal.
   - Example:
     ```solidity
     (uint256 balance, uint256 daysRemaining) = vault.getWithdrawalInfo(msg.sender);
     ```

5. **Withdraw Funds**:
   - After the 7-day lock period, call `withdraw(uint256 amount)` to retrieve your funds.
   - Example:
     ```solidity
     vault.withdraw(1 ether);
     ```

## Testing
The SafeVault project includes a comprehensive test suite built with Foundry, achieving **100% code coverage** across all contracts (`Vault.sol`, `ReentrantAttacker.sol`, `ReceiverReverts.sol`).

### Test Breakdown
- **Unit Tests (`VaultTest.t.sol`)**:
  - 17 tests covering:
    - Whitelisting (success, reverts for duplicates, max users).
    - Deposits (success, reverts for non-whitelisted or low amounts).
    - Withdrawals (success, reverts for locked funds, insufficient balance, or failed transfers).
    - Lock time extensions (success, reverts for zero balance).
    - Event emissions and withdrawal info retrieval.
    - Example:
      ```bash
      forge test --match-path test/Vault.t.sol
      ```

- **Fuzz Tests (`VaultFuzzTest.t.sol`)**:
  - 3 tests with 256 runs each:
    - `testFuzz_Deposit_Whitelisted`: Tests deposits with random amounts (0 to 100 Ether) and users.
    - `testFuzz_ExtendLockTime`: Tests lock time extensions with random days (1 to 365).
    - `testFuzz_Whitelist_MaxLimit`: Tests whitelisting up to the max user limit with random addresses.
    - Example:
      ```bash
      forge test --match-path test/VaultFuzzTest.t.sol
      ```

- **Invariant Tests (`VaultInvariantTest.t.sol`)**:
  - 2 tests with 100 runs and 10,000 calls each:
    - `invariant_totalLockedIsSumOfUserBalances`: Ensures `totalLocked` equals the sum of whitelisted users' balances.
    - `invariant_whitelistedUserCountMatches`: Verifies the `whitelistedUserCount` matches the actual number of whitelisted users.
    - Uses `VaultHandler.t.sol` to simulate randomized interactions.
    - Example:
      ```bash
      forge test --match-path test/VaultInvariantTest.t.sol
      ```

### Running Tests
To run the full test suite with coverage:
```bash
forge test
forge coverage
```

### Coverage Results
As shown in the provided output, the project achieves:
- **100% Line Coverage** (79/79 lines)
- **100% Statement Coverage** (80/80 statements)
- **100% Branch Coverage** (16/16 branches)
- **100% Function Coverage** (15/15 functions)

## Security
SafeVault incorporates several security measures:
- **Reentrancy Protection**: Uses `ReentrancyGuard` to prevent reentrancy attacks, validated by `test_RevertOnReentrancyAttack`.
- **Custom Errors**: Descriptive errors (e.g., `NotWhitelisted`, `FundsLocked`) for clear failure reporting.
- **Ether Transfer Safety**: Checks for successful Ether transfers during withdrawals, tested with `ReceiverReverts.sol`.
- **Input Validation**: Enforces minimum deposits, max users, and whitelist checks.
- **Extensive Testing**: Unit, fuzz, and invariant tests ensure robust behavior under various conditions.

### Known Considerations
- The contract assumes a maximum of 100 users (`MAX_USERS`). Adjust this constant if needed for larger-scale deployments.
- Gas costs for whitelisting and deposits are optimized, but large-scale operations (e.g., whitelisting 100 users) may require batch processing in production.

## Contributing
Contributions are welcome! To contribute:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes (`git commit -m "Add your feature"`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a pull request.

Please include tests for any new features or bug fixes and ensure all tests pass.

## Author
- **Therock Ani**  
  Email: anitherock44@gmail.com 