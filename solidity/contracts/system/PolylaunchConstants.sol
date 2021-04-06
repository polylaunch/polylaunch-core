// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

/// @title PolylaunchConstants
/// @notice Constants for development testnet usages; tuned for testing and
///         fast iteration rather than security. These should NOT be deployed
///         on mainnet or mainnet-like ("staging") environments.
library PolylaunchConstants {
    // Voting Parameters
    uint256 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant VOTING_PERIOD = 15; // 5 blocks

    // Timelock parameters
    uint256 public constant EXECUTION_DELAY = 1 days; // 5 blocks
    uint256 public constant GRACE_PERIOD = 2 days; // 10 blocks

    // BidShare parameters these MUST add up to exactly 100, always
    uint256 public constant NFT_SALE_PERCENTAGE_SENT_TO_PREV_OWNER = 0;
    uint256 public constant NFT_SALE_PERCENTAGE_SENT_TO_CREATOR = 10e18;
    uint256 public constant NFT_SALE_PERCENTAGE_SENT_TO_OWNER = 90e18;

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

    function getPrevOwner() external pure returns (uint256) {
        return NFT_SALE_PERCENTAGE_SENT_TO_PREV_OWNER;
    }

    function getCreator() external pure returns (uint256) {
        return NFT_SALE_PERCENTAGE_SENT_TO_CREATOR;
    }

    function getOwner() external pure returns (uint256) {
        return NFT_SALE_PERCENTAGE_SENT_TO_OWNER;
    }

    function getExcess() external pure returns (uint256) {
        return SYSTEM_EXCESS_ALLOCATION_COEFFICIENT;
    }


}
