// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {console} from "forge-std/console.sol";

contract DeployVault is Script {
    // function setUp() public {}

    function run() public returns (Vault) {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy the Vault contract
        Vault vault = new Vault();

        // Stop broadcasting
        vm.stopBroadcast();

        return vault;
    }
}
