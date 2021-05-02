// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {LaunchUtils} from "./LaunchUtils.sol";
import {LaunchLogger} from "./LaunchLogger.sol";
import "../../interfaces/IPolyVault.sol";
import "../../interfaces/ILaunchFactory.sol";

/**
 * @author PolyLaunch Protocol
 * @title Launch Vault
 * @notice Library containing functions that handle vault functions
 */

library LaunchVault {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    using LaunchUtils for LaunchUtils.Data;

    /**
     * @notice activate deposit into the PolyVault
     * @param vaultId the unique identifier of the vault the launcher wants to deploy funds to, refer to VaultRegistry
     * @param self Data storage struct for the launch
     */
    function deposit(LaunchUtils.Data storage self, uint256 vaultId) internal {
        require(
            !self.yieldActivated,
            "LaunchVault: Your funds are already in a vault pool"
        );
        require(!self.isRefundMode, "LaunchVault: The launch is in refund mode");
        if (block.timestamp > self.END && !self.launchSuccessful) {
            if (self.totalFunding > self.MINIMUM_FUNDING) {
                self.launchSuccessful = true;
                self.launcherTapRate = self.totalFunding.div(self.launcherVestingPeriod);
            }
        }
        require(
            self.launchSuccessful,
            "LaunchVault: The launch was not successful or has not concluded"
        );
        uint256 _startingBalance = self.stable.balanceOf(address(this));
        require(
            _startingBalance != 0,
            "LaunchVault: No funds to deposit into the Vault"
        );
        address vaultRegistry =
            ILaunchFactory(self.launchFactory).getVaultRegistryAddress();
        IPolyVault(address(this))._deposit(
            vaultRegistry,
            vaultId,
            _startingBalance,
            self.stable,
            self.polylaunchSystem
        );
        self.yieldActivated = true;
    }

    /**
     * @notice exit from a PolyVault
     * @param self Data storage struct for the launch
     */
    function exitFromVault(LaunchUtils.Data storage self) internal {
        require(self.yieldActivated, "LaunchVault: Yield has not been activated");
        address vaultRegistry =
            ILaunchFactory(self.launchFactory).getVaultRegistryAddress();
        IPolyVault(address(this))._exitFromVault(vaultRegistry, self.stable, self.polylaunchSystem);
        self.yieldActivated = false;
    }

}
