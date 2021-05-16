// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

/// @title PolylaunchConstants
/// @notice Constants for development testnet usages; tuned for testing and
///         fast iteration rather than security. These should NOT be deployed
///         on mainnet or mainnet-like ("staging") environments.
library PolylaunchConstants {
    // Voting Parameters
    uint256 public constant VOTING_DELAY = 1 minutes; // 1 block
    uint256 public constant VOTING_PERIOD = 1 days; // 5 blocks

    // Timelock parameters
    uint256 public constant EXECUTION_DELAY = 1 days; // 5 blocks
    uint256 public constant GRACE_PERIOD = 2 days; // 10 blocks

    //Excess System allocation for vaults
    uint256 public constant SYSTEM_EXCESS_ALLOCATION_COEFFICIENT = 2;
    // Getters for easy access
    function getVotingDelay() external pure returns (uint256) {
        return VOTING_DELAY;
    }

    function getExecutionDelay() external pure returns (uint256) {
        return EXECUTION_DELAY;
    }

    function getVotingPeriod() external pure returns (uint256) {
        return VOTING_PERIOD;
    }

    function getGracePeriod() external pure returns (uint256) {
        return GRACE_PERIOD;
    }

    function getExcess() external pure returns (uint256) {
        return SYSTEM_EXCESS_ALLOCATION_COEFFICIENT;
    }


}
