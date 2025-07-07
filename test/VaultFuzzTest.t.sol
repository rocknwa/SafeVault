// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../script/DeployVault.s.sol";
import {Vault} from "../src/Vault.sol";

/// @title VaultFuzzTest
/// @author Therock Ani
/// @notice Fuzz tests for the Vault contract to verify behavior with randomized inputs.
/// @dev Tests key functionalities like deposits, lock time extensions, and whitelisting using fuzzing.
contract VaultFuzzTest is Test {
    /// @notice The Vault contract instance being tested.
    Vault internal vault;

    /// @notice Mapping to track seen addresses to avoid duplicates in whitelisting tests.
    mapping(address => bool) seen;

    /// @notice Sets up the test environment by deploying a new Vault instance.
    /// @dev Uses the DeployVault script to ensure a fresh contract state for each test.
    function setUp() public {
        DeployVault deployScript = new DeployVault();
        vault = deployScript.run();
    }

    /// @notice Tests depositing funds for whitelisted users with varying amounts.
    /// @dev Verifies that deposits below 1 ether revert and valid deposits update balances correctly.
    /// @param fuzzAmount The amount to deposit, bounded between 0 and 100 ether.
    /// @param fuzzAddr The user address, bounded to a nonzero value.
    function testFuzz_Deposit_Whitelisted(uint96 fuzzAmount, uint160 fuzzAddr) public {
        // Bound amount to a reasonable upper limit (for gas), and fuzzAddr to nonzero
        uint256 amount = bound(uint256(fuzzAmount), 0, 100 ether);
        address fuzzUser = address(uint160(bound(fuzzAddr, 1, type(uint160).max)));

        vm.deal(fuzzUser, 100 ether);
        vm.prank(fuzzUser);
        vault.whitelistUser();

        if (amount < 1 ether) {
            vm.expectRevert(Vault.DepositTooSmall.selector);
            vm.prank(fuzzUser);
            vault.deposit{value: amount}();
        } else {
            vm.prank(fuzzUser);
            vault.deposit{value: amount}();

            (uint256 bal,,) = vault.users(fuzzUser);
            assertEq(bal, amount, "User balance does not match deposited amount");
        }
    }

    /// @notice Tests extending lock time for whitelisted users with varying durations.
    /// @dev Verifies that lock time extensions update the lock end time correctly.
    /// @param fuzzDays The number of days to extend the lock, bounded between 1 and 365.
    /// @param fuzzAddr The user address, bounded to a nonzero value.
    function testFuzz_ExtendLockTime(uint16 fuzzDays, uint160 fuzzAddr) public {
        uint256 Days = bound(uint256(fuzzDays), 1, 365);
        address fuzzUser = address(uint160(bound(fuzzAddr, 1, type(uint160).max)));

        vm.deal(fuzzUser, 10 ether);
        vm.prank(fuzzUser);
        vault.whitelistUser();

        vm.prank(fuzzUser);
        vault.deposit{value: 1 ether}();

        (, uint256 oldTime,) = vault.users(fuzzUser);
        vm.prank(fuzzUser);
        vault.extendLockTime(Days);

        uint256 expectedTime = oldTime + Days * vault.SECONDS_PER_DAY();
        (, uint256 newTime,) = vault.users(fuzzUser);
        assertEq(newTime, expectedTime, "Lock end time does not match expected value");
    }

    /// @notice Tests whitelisting up to the maximum user limit.
    /// @dev Ensures that whitelisting fails when MAX_USERS is reached and counts are accurate.
    /// @param fuzzUsers An array of user addresses to attempt whitelisting.
    function testFuzz_Whitelist_MaxLimit(uint160[] memory fuzzUsers) public {
        vm.assume(fuzzUsers.length > 0);
        uint256 max = vault.MAX_USERS();
        uint256 n = bound(fuzzUsers.length, 1, max + 10);

        uint256 whitelisted = 0;
        for (uint256 i = 0; i < n; i++) {
            address user = address(uint160(bound(fuzzUsers[i], 1, type(uint160).max)));
            // Skip duplicates and zero
            if (seen[user]) continue;
            seen[user] = true;
            if (whitelisted < max) {
                vm.prank(user);
                vault.whitelistUser();
                whitelisted++;
            } else {
                vm.expectRevert(Vault.MaxUsersReached.selector);
                vm.prank(user);
                vault.whitelistUser();
            }
        }
        assertLe(vault.whitelistedUserCount(), max, "Whitelisted user count exceeds MAX_USERS");
    }
}
