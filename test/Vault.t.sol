// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../script/DeployVault.s.sol";
import {Vault} from "../src/Vault.sol";
import {ReceiverReverts} from "../src/ReceiverReverts.sol";
import {ReentrantAttacker} from "../src/ReentrantAttacker.sol";

/// @title VaultTest
/// @author Therock Ani
/// @notice Unit tests for the Vault contract to verify core functionalities.
/// @dev Tests whitelisting, deposits, withdrawals, lock time extensions, and event emissions using Foundry.
contract VaultTest is Test {
    /// @notice The Vault contract instance being tested.
    Vault internal vault;

    /// @notice Test user address 1.
    address internal user1;

    /// @notice Test user address 2.
    address internal user2;

    /// @notice The minimum deposit amount required by the Vault (1 ether).
    uint256 constant MIN_DEPOSIT = 1 ether;

    /// @notice The lock period for deposits (7 days).
    uint256 constant LOCK_PERIOD = 7 days;

    /// @notice Sets up the test environment by deploying the Vault and initializing users.
    /// @dev Deploys a new Vault instance, creates two test users, and funds them with 1000 ether each.
    function setUp() public {
        user1 = vm.addr(0xB0B);
        user2 = vm.addr(0xCAFE);
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);

        DeployVault deployScript = new DeployVault();
        vault = deployScript.run();
    }

    /// @notice Tests successful whitelisting of a user.
    /// @dev Verifies that a user is marked as whitelisted, has zero balance, and increments the whitelist count.
    function testWhitelistUserSuccess() public {
        vm.startPrank(user1);
        vault.whitelistUser();

        (uint256 balance,, bool isWhitelisted) = vault.users(user1);
        assertEq(isWhitelisted, true, "User1 should be whitelisted");
        assertEq(balance, 0, "User1 balance should be zero");
        assertEq(vault.whitelistedUserCount(), 1, "Whitelisted user count should be 1");
    }

    /// @notice Tests that whitelisting an already whitelisted user reverts.
    /// @dev Expects AlreadyWhitelisted error when attempting to whitelist user1 twice.
    function testWhitelistRevertsIfAlreadyWhitelisted() public {
        vm.startPrank(user1);
        vault.whitelistUser();
        vm.expectRevert(Vault.AlreadyWhitelisted.selector);
        vault.whitelistUser();
    }

    /// @notice Tests that whitelisting fails when MAX_USERS is reached.
    /// @dev Whitelists MAX_USERS users, then expects MaxUsersReached error for an additional user.
    function testWhitelistRevertsIfMaxUsers() public {
        for (uint256 i = 0; i < vault.MAX_USERS(); i++) {
            address newUser = vm.addr(uint160(i + 1000));
            vm.prank(newUser);
            vault.whitelistUser();
        }
        address overflow = vm.addr(999_999);
        vm.expectRevert(Vault.MaxUsersReached.selector);
        vm.prank(overflow);
        vault.whitelistUser();
    }

    /// @notice Tests that deposits from non-whitelisted users revert.
    /// @dev Expects NotWhitelisted error when user1 attempts to deposit without being whitelisted.
    function testDepositRevertsIfNotWhitelisted() public {
        vm.expectRevert(Vault.NotWhitelisted.selector);
        vm.prank(user1);
        vault.deposit{value: MIN_DEPOSIT}();
    }

    /// @notice Tests that deposits below the minimum amount revert.
    /// @dev Whitelists user1, then expects DepositTooSmall error for a deposit less than MIN_DEPOSIT.
    function testDepositRevertsIfBelowMin() public {
        vm.prank(user1);
        vault.whitelistUser();
        vm.expectRevert(Vault.DepositTooSmall.selector);
        vm.prank(user1);
        vault.deposit{value: MIN_DEPOSIT - 1 wei}();
    }

    /// @notice Tests successful deposit by a whitelisted user.
    /// @dev Verifies balance, whitelist status, deposit timestamp, and totalLocked after a valid deposit.
    function testDepositSuccess() public {
        vm.prank(user1);
        vault.whitelistUser();

        vm.prank(user1);
        vault.deposit{value: MIN_DEPOSIT}();

        (uint256 balance, uint256 lastDeposit, bool isWhitelisted) = vault.users(user1);
        assertEq(balance, MIN_DEPOSIT, "User balance should equal MIN_DEPOSIT");
        assertEq(isWhitelisted, true, "User should remain whitelisted");
        assertEq(lastDeposit, block.timestamp, "Last deposit timestamp should match current block time");
        assertEq(vault.totalLocked(), MIN_DEPOSIT, "Total locked should equal MIN_DEPOSIT");
    }

    /// @notice Tests that withdrawals from non-whitelisted users revert.
    /// @dev Expects NotWhitelisted error when user1 attempts to withdraw without being whitelisted.
    function testWithdrawRevertsIfNotWhitelisted() public {
        vm.expectRevert(Vault.NotWhitelisted.selector);
        vm.prank(user1);
        vault.withdraw(MIN_DEPOSIT);
    }

    /// @notice Tests that withdrawals exceeding the user's balance revert.
    /// @dev Deposits MIN_DEPOSIT, waits past lock period, and expects InsufficientBalance error for a larger withdrawal.
    function testWithdrawRevertsIfInsufficientBalance() public {
        vm.prank(user1);
        vault.whitelistUser();
        vm.prank(user1);
        vault.deposit{value: MIN_DEPOSIT}();

        vm.warp(block.timestamp + LOCK_PERIOD);

        vm.expectRevert(Vault.InsufficientBalance.selector);
        vm.prank(user1);
        vault.withdraw(MIN_DEPOSIT + 1 ether);
    }

    /// @notice Tests that withdrawals before the lock period expires revert.
    /// @dev Deposits MIN_DEPOSIT and expects FundsLocked error for an immediate withdrawal attempt.
    function testWithdrawRevertsIfFundsLocked() public {
        vm.prank(user1);
        vault.whitelistUser();

        vm.prank(user1);
        vault.deposit{value: MIN_DEPOSIT}();

        vm.expectRevert(Vault.FundsLocked.selector);
        vm.prank(user1);
        vault.withdraw(MIN_DEPOSIT);
    }

    /// @notice Tests successful withdrawal after the lock period.
    /// @dev Verifies balance updates, totalLocked, and ether transfer to the user after a valid withdrawal.
    function testWithdrawSuccess() public {
        vm.prank(user1);
        vault.whitelistUser();

        vm.deal(user1, 10 ether);
        vm.prank(user1);
        vault.deposit{value: MIN_DEPOSIT}();

        vm.warp(block.timestamp + LOCK_PERIOD);

        uint256 userBalBefore = user1.balance;
        vm.prank(user1);
        vault.withdraw(MIN_DEPOSIT);

        (uint256 balance,,) = vault.users(user1);
        assertEq(balance, 0, "User balance should be zero after withdrawal");
        assertEq(vault.totalLocked(), 0, "Total locked should be zero");
        assertEq(user1.balance, userBalBefore + MIN_DEPOSIT, "User should receive withdrawn ether");
    }

    /// @notice Tests getWithdrawalInfo for a user with no deposits.
    /// @dev Verifies that balance and days remaining are zero for a non-depositing user.
    function testGetWithdrawalInfoNoDeposit() public view {
        (uint256 balance, uint256 daysRemaining) = vault.getWithdrawalInfo(user1);
        assertEq(balance, 0, "Balance should be zero for non-depositor");
        assertEq(daysRemaining, 0, "Days remaining should be zero for non-depositor");
    }

    /// @notice Tests getWithdrawalInfo for a user with a deposit.
    /// @dev Verifies balance and days remaining at deposit time and after a time warp.
    function testGetWithdrawalInfoWithDeposit() public {
        vm.prank(user1);
        vault.whitelistUser();

        vm.prank(user1);
        vault.deposit{value: MIN_DEPOSIT}();

        (uint256 bal, uint256 daysR) = vault.getWithdrawalInfo(user1);
        assertEq(bal, MIN_DEPOSIT, "Balance should equal MIN_DEPOSIT");
        assertEq(daysR, 7, "Days remaining should be 7 at deposit time");

        vm.warp(block.timestamp + 2 days);

        (,, bool isWhitelisted) = vault.users(user1);
        assertEq(isWhitelisted, true, "User should remain whitelisted");

        (bal, daysR) = vault.getWithdrawalInfo(user1);
        assertEq(bal, MIN_DEPOSIT, "Balance should still equal MIN_DEPOSIT");
        assertEq(daysR, 5, "Days remaining should be 5 after 2 days");
    }

    /// @notice Tests that extending lock time without a balance reverts.
    /// @dev Expects NoBalanceToLock error when user1 tries to extend lock time with zero balance.
    function testExtendLockTimeRevertsIfNoBalance() public {
        vm.prank(user1);
        vault.whitelistUser();
        vm.expectRevert(Vault.NoBalanceToLock.selector);
        vm.prank(user1);
        vault.extendLockTime(1);
    }

    /// @notice Tests successful lock time extension.
    /// @dev Verifies that extending lock time updates the lock end time while preserving balance.
    function testExtendLockTimeSuccess() public {
        vm.prank(user1);
        vault.whitelistUser();
        vm.prank(user1);
        vault.deposit{value: MIN_DEPOSIT}();

        (uint256 oldBal, uint256 oldLastDeposit,) = vault.users(user1);

        vm.prank(user1);
        vault.extendLockTime(3);

        (uint256 newBal, uint256 newLastDeposit,) = vault.users(user1);
        assertEq(oldBal, newBal, "Balance should remain unchanged");
        assertEq(newLastDeposit, oldLastDeposit + 3 days, "Lock time should extend by 3 days");
    }

    /// @notice Tests that expected events are emitted during key operations.
    /// @dev Verifies UserWhitelisted, FundsDeposited, FundsWithdrawn, and LockTimeExtended events.
    function testEventEmissions() public {
        vm.expectEmit(true, false, false, true);
        emit Vault.UserWhitelisted(user1);
        vm.prank(user1);
        vault.whitelistUser();

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Vault.FundsDeposited(user1, MIN_DEPOSIT);
        vault.deposit{value: MIN_DEPOSIT}();

        vm.warp(block.timestamp + LOCK_PERIOD);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Vault.FundsWithdrawn(user1, MIN_DEPOSIT);
        vault.withdraw(MIN_DEPOSIT);

        vm.prank(user1);
        vault.deposit{value: MIN_DEPOSIT}();
        vm.prank(user1);
        vm.expectEmit(true, false, true, true);
        emit Vault.LockTimeExtended(user1, 2, block.timestamp + 2 days);
        vault.extendLockTime(2);
    }

    /// @notice Tests that withdrawal fails when the ether transfer reverts.
    /// @dev Uses ReceiverReverts contract to simulate a failed transfer; expects EtherTransferFailed error.
    function testWithdrawRevertsIfTransferFails() public {
        ReceiverReverts badReceiver = new ReceiverReverts();
        vm.prank(address(badReceiver));
        vault.whitelistUser();
        vm.deal(address(badReceiver), 1 ether);

        vm.startPrank(address(badReceiver));
        vault.deposit{value: 1 ether}();
        vm.warp(block.timestamp + LOCK_PERIOD);

        vm.expectRevert(abi.encodeWithSelector(Vault.EtherTransferFailed.selector, address(badReceiver), 1 ether));
        vault.withdraw(1 ether);
        vm.stopPrank();
    }

    function test_RevertOnReentrancyAttack() public {
        vm.startPrank(user1);
        vault.whitelistUser();
        vault.deposit{value: 1 ether}();
        vm.stopPrank();

        ReentrantAttacker attackerContract = new ReentrantAttacker(vault);
        vm.prank(address(attackerContract));
        vault.whitelistUser();
        vm.deal(address(attackerContract), 2 ether);

        vm.startPrank(address(attackerContract));
        vault.deposit{value: 1 ether}();
        vm.warp(block.timestamp + LOCK_PERIOD);
        vm.expectRevert();
        attackerContract.attack{value: 1 ether}();
    }
}
 