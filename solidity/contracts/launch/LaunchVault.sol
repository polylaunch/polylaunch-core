// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {LaunchUtils} from "./LaunchUtils.sol";
import {LaunchLogger} from "./LaunchLogger.sol";
import "../../interfaces/IPolyVault.sol";
import "../../interfaces/ILaunchFactory.sol";
import "../../interfaces/ICErc20.sol";
import "../../interfaces/ILendingPool.sol";

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
            "funds already deployed"
        );
        require(!self.isRefundMode, "in refund mode");
        if (block.timestamp > self.END && !self.launchSuccessful) {
            if (self.totalFunding > self.MINIMUM_FUNDING) {
                self.launchSuccessful = true;
                self.launcherTapRate = self.totalFunding.div(self.launcherVestingPeriod);
            }
        }
        require(
            self.launchSuccessful,
            "launch unsuccessful"
        );
        uint256 _startingBalance = self.stable.balanceOf(address(this));
        require(
            _startingBalance != 0,
            "no depositable funds"
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
        require(self.yieldActivated, "yield not activated");
        address vaultRegistry =
            ILaunchFactory(self.launchFactory).getVaultRegistryAddress();
        IPolyVault(address(this))._exitFromVault(vaultRegistry, self.stable, self.polylaunchSystem);
        self.yieldActivated = false;
    }

    function withdrawComp(LaunchUtils.Data storage self) internal {
        IERC20 comp = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
        ICompTroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B).claimComp(address(this));
        comp.safeTransfer(self.fundRecipient, comp.balanceOf(address(this)));
    }

    function withdrawAave(LaunchUtils.Data storage self, address[] calldata _asset) internal {
        IERC20 aave = IERC20(0x4da27a545c0c5B758a6BA100e3a049001de870f5);
        IStkAave(0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5).claimRewards(_asset,address(this), type(uint).max);
        aave.safeTransfer(self.fundRecipient, aave.balanceOf(address(this)));
    }

}
