// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployVault} from "../script/DeployVault.s.sol";
import {Vault} from "../src/Vault.sol";
import {VaultHandler} from "./VaultHandler.t.sol";

/// @title VaultInvariantTest
/// @author Therock Ani
/// @notice Invariant tests to verify the Vault contract's state properties under randomized interactions.
/// @dev Uses a handler to simulate actions and checks invariants like total locked funds and whitelist counts.
contract VaultInvariantTest is Test {
    /// @notice The Vault contract instance being tested.
    Vault internal vault;

    /// @notice The handler contract that simulates interactions with the Vault.
    VaultHandler internal handler;

    /// @notice Sets up the test environment by deploying the Vault and handler.
    /// @dev Deploys a new Vault instance and registers the handler for invariant testing.
    function setUp() public {
        DeployVault deployScript = new DeployVault();
        vault = deployScript.run();
        handler = new VaultHandler(vault);
        targetContract(address(handler));
    }

    /// @notice Invariant: The total locked amount equals the sum of all whitelisted users' balances.
    /// @dev Loops through possible user addresses to sum whitelisted users' balances and compares to totalLocked.
    function invariant_totalLockedIsSumOfUserBalances() public view {
        uint256 sum = 0;
        for (uint256 i = 1; i <= vault.MAX_USERS(); ++i) {
            address user = address(uint160(i));
            (uint256 bal,, bool isWhitelisted) = vault.users(user);
            if (isWhitelisted) sum += bal;
        }
        assertEq(vault.totalLocked(), sum, "totalLocked does not match sum of whitelisted user balances");
    }

    /// @notice Invariant: The whitelisted user count matches the actual number of whitelisted users.
    /// @dev Counts whitelisted users and ensures it matches whitelistedUserCount and respects MAX_USERS.
    function invariant_whitelistedUserCountMatches() public view {
        uint256 count = 0;
        for (uint256 i = 1; i <= vault.MAX_USERS(); ++i) {
            address user = address(uint160(i));
            (,, bool isWhitelisted) = vault.users(user);
            if (isWhitelisted) count++;
        }
        assertEq(vault.whitelistedUserCount(), count, "whitelistedUserCount does not match actual count");
        assertLe(count, vault.MAX_USERS(), "whitelistedUserCount exceeds MAX_USERS");
    }
}
