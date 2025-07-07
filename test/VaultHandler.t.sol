// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Vault} from "../src/Vault.sol";
import {Test} from "forge-std/Test.sol";

/// @title VaultHandler
/// @author Therock Ani
/// @notice A handler contract for invariant testing of the Vault contract.
/// @dev Simulates randomized user interactions with the Vault to explore state transitions.
contract VaultHandler is Test {
    /// @notice The Vault contract instance being tested.
    Vault public vault;

    /// @notice Array of pre-generated user addresses for testing.
    /// @dev Stores addresses 0x1 to 0x64 (1 to MAX_USERS) for consistent fuzzing.
    address[] public users;

    /// @notice The maximum number of users allowed in the Vault.
    uint256 public constant MAX_USERS = 100;

    /// @notice Initializes the handler with a Vault instance and pre-generates user addresses.
    /// @dev Creates a list of user addresses (1 to MAX_USERS) for use in tests.
    /// @param _vault The address of the Vault contract to test.
    constructor(Vault _vault) {
        vault = _vault;
        for (uint160 i = 1; i <= MAX_USERS; ++i) {
            users.push(address(i));
        }
    }

    /// @notice Simulates whitelisting a user from the pre-generated list.
    /// @dev Uses try/catch to prevent reverts from halting invariant tests.
    /// @param idx The index of the user in the users array, bounded to 0–99.
    function whitelistUser(uint256 idx) public {
        idx = bound(idx, 0, users.length - 1);
        address user = users[idx];
        vm.prank(user);
        try vault.whitelistUser() {} catch {}
    }

    /// @notice Simulates a user depositing funds into the Vault.
    /// @dev Funds the user with ether and calls deposit; uses try/catch to handle reverts.
    /// @param idx The index of the user in the users array, bounded to 0–99.
    /// @param amount The amount of ether to deposit, in wei.
    function deposit(uint256 idx, uint256 amount) public {
        idx = bound(idx, 0, users.length - 1);
        address user = users[idx];
        vm.deal(user, amount);
        vm.prank(user);
        try vault.deposit{value: amount}() {} catch {}
    }

    /// @notice Simulates a user withdrawing funds after advancing time.
    /// @dev Advances time between 7 and 30 days; uses try/catch to handle reverts.
    /// @param idx The index of the user in the users array, bounded to 0–99.
    /// @param amount The amount of ether to withdraw, in wei.
    /// @param timeJump The number of seconds to advance time, bounded between 7 and 30 days.
    function withdraw(uint256 idx, uint256 amount, uint256 timeJump) public {
        idx = bound(idx, 0, users.length - 1);
        address user = users[idx];
        vm.warp(block.timestamp + bound(timeJump, 7 days, 30 days));
        vm.prank(user);
        try vault.withdraw(amount) {} catch {}
    }

    /// @notice Simulates a user extending their lock period.
    /// @dev Uses try/catch to handle reverts during invariant testing.
    /// @param idx The index of the user in the users array, bounded to 0–99.
    /// @param daysToAdd The number of days to extend the lock period.
    function extendLockTime(uint256 idx, uint256 daysToAdd) public {
        idx = bound(idx, 0, users.length - 1);
        address user = users[idx];
        vm.prank(user);
        try vault.extendLockTime(daysToAdd) {} catch {}
    }
}
