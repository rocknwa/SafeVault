// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Vault
/// @author Therock Ani
/// @notice A contract for managing user deposits and withdrawals with a lock period and whitelist.
/// @dev Implements a vault where whitelisted users can deposit ether, lock it for a period, and withdraw after the lock expires. Uses ReentrancyGuard for security.
contract Vault is ReentrancyGuard {
    /// @notice Structure to store user data.
    /// @dev Contains the user's balance, last deposit timestamp, and whitelist status.
    struct User {
        uint256 balance; // User's deposited balance in wei
        uint256 lastDepositTime; // Timestamp of the user's last deposit
        bool isWhitelisted; // Whether the user is whitelisted
    }

    /// @notice Mapping of user addresses to their data.
    mapping(address => User) public users;

    /// @notice Tracks the number of whitelisted users.
    uint256 public whitelistedUserCount;

    /// @notice Total amount of ether locked in the vault.
    uint256 public totalLocked;

    /// @notice Maximum number of users that can be whitelisted.
    uint256 public constant MAX_USERS = 100;

    /// @notice Minimum deposit amount required (1 ether).
    uint256 public constant MIN_DEPOSIT = 1 ether;

    /// @notice Lock period for deposits (7 days).
    uint256 public constant LOCK_PERIOD = 7 days;

    /// @notice Seconds in a day, used for time calculations.
    uint256 public constant SECONDS_PER_DAY = 86_400;

    /// @notice Error thrown when a deposit is below MIN_DEPOSIT.
    error DepositTooSmall();

    /// @notice Error thrown when the maximum number of users is reached.
    error MaxUsersReached();

    /// @notice Error thrown when a withdrawal exceeds the user's balance.
    error InsufficientBalance();

    /// @notice Error thrown when attempting to withdraw before the lock period expires.
    error FundsLocked();

    /// @notice Error thrown when an ether transfer fails during withdrawal.
    /// @param recipient The address that failed to receive the ether.
    /// @param amount The amount of ether that failed to transfer.
    error EtherTransferFailed(address recipient, uint256 amount);

    /// @notice Error thrown when attempting to extend lock time with no balance.
    error NoBalanceToLock();

    /// @notice Error thrown when a non-whitelisted user attempts an action.
    error NotWhitelisted();

    /// @notice Error thrown when attempting to whitelist an already whitelisted user.
    error AlreadyWhitelisted();

    /// @notice Emitted when a user extends their lock period.
    /// @param user The address of the user.
    /// @param additionalDays The number of days added to the lock period.
    /// @param newLastDepositTime The new lock end timestamp.
    event LockTimeExtended(address indexed user, uint256 additionalDays, uint256 indexed newLastDepositTime);

    /// @notice Emitted when a user deposits funds.
    /// @param user The address of the user who deposited.
    /// @param amount The amount deposited in wei.
    event FundsDeposited(address indexed user, uint256 indexed amount);

    /// @notice Emitted when a user withdraws funds.
    /// @param user The address of the user who withdrew.
    /// @param amount The amount withdrawn in wei.
    event FundsWithdrawn(address indexed user, uint256 indexed amount);

    /// @notice Emitted when a user is whitelisted.
    /// @param user The address of the whitelisted user.
    event UserWhitelisted(address indexed user);

    /// @notice Whitelists a user, allowing them to deposit and withdraw funds.
    /// @dev Checks for existing whitelist status and MAX_USERS limit; increments whitelistedUserCount.
    function whitelistUser() external nonReentrant {
        if (users[msg.sender].isWhitelisted) revert AlreadyWhitelisted();
        if (whitelistedUserCount >= MAX_USERS) revert MaxUsersReached();

        users[msg.sender].isWhitelisted = true;
        whitelistedUserCount++;
        emit UserWhitelisted(msg.sender);
    }

    /// @notice Deposits ether into the vault.
    /// @dev Requires the user to be whitelisted and the deposit to meet MIN_DEPOSIT. Updates balance and totalLocked.
    function deposit() external payable nonReentrant {
        if (!users[msg.sender].isWhitelisted) revert NotWhitelisted();
        if (msg.value < MIN_DEPOSIT) revert DepositTooSmall();

        User storage user = users[msg.sender];
        user.lastDepositTime = block.timestamp;
        user.balance += msg.value;
        totalLocked += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    /// @notice Withdraws ether from the vault.
    /// @dev Requires the user to be whitelisted, have sufficient balance, and have passed the lock period. Transfers ether to the user.
    /// @param amount The amount to withdraw in wei.
    function withdraw(uint256 amount) external nonReentrant {
        if (!users[msg.sender].isWhitelisted) revert NotWhitelisted();
        User storage user = users[msg.sender];
        if (user.balance < amount) revert InsufficientBalance();
        if (block.timestamp < user.lastDepositTime + LOCK_PERIOD) revert FundsLocked();

        user.balance -= amount;
        totalLocked -= amount;

        emit FundsWithdrawn(msg.sender, amount);

        (bool sent,) = msg.sender.call{value: amount}("");
        if (!sent) revert EtherTransferFailed(msg.sender, amount);
    }

    /// @notice Retrieves a user's balance and days remaining until withdrawal is allowed.
    /// @dev Calculates days remaining based on the lock period and current timestamp.
    /// @param user The address of the user to query.
    /// @return balance The user's balance in wei.
    /// @return daysRemaining The number of days until the user's funds can be withdrawn.
    function getWithdrawalInfo(address user) external view returns (uint256 balance, uint256 daysRemaining) {
        User storage userData = users[user];
        balance = userData.balance;
        if (balance > 0) {
            uint256 unlockTime = userData.lastDepositTime + LOCK_PERIOD;
            if (block.timestamp < unlockTime) {
                uint256 remainingSeconds = unlockTime - block.timestamp;
                daysRemaining = remainingSeconds / SECONDS_PER_DAY;
            }
        }
    }

    /// @notice Extends the lock period for a user's funds.
    /// @dev Requires the user to have a non-zero balance. Updates lastDepositTime by adding additional days.
    /// @param additionalDays The number of days to extend the lock period.
    function extendLockTime(uint256 additionalDays) external nonReentrant {
        User storage user = users[msg.sender];
        if (user.balance == 0) revert NoBalanceToLock();

        user.lastDepositTime += additionalDays * SECONDS_PER_DAY;
        emit LockTimeExtended(msg.sender, additionalDays, user.lastDepositTime);
    }
}
