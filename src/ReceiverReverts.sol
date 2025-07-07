// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @dev This contract is used to test the Vault contract's behavior when receiving Ether.
/// @dev It reverts on receiving Ether, which can be used to test how the Vault handles such scenarios.
/// @dev It is not meant to be used in production but rather for testing purposes.
contract ReceiverReverts {
    receive() external payable {
        revert();
    }
}
