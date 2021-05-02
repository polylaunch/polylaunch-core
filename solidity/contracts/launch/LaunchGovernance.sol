pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {LaunchUtils} from "./LaunchUtils.sol";
import {LaunchVault} from "./LaunchVault.sol";
import {LaunchRedemption} from "./LaunchRedemption.sol";
import {IVentureBond} from "../../interfaces/IVentureBond.sol";
import {LaunchLogger} from "./LaunchLogger.sol";

library LaunchGovernance {
    using SafeMath for uint256;
    using SafeMath for uint64;
    using SafeERC20 for IERC20;

    using LaunchUtils for LaunchUtils.Data;

    /**
     * @notice Puts the launch into refund mode, which allows contributors to claim back their USD proportional to their token balance
     * @param self Data struct associated with the launch
     */
    function initiateRefundMode(LaunchUtils.Data storage self) internal {
        require(
            self.isRefundMode == false,
            "initiateRefundMode: Launch is in refund mode"
        );
        self.isRefundMode = true;
        if (self.yieldActivated){
        LaunchVault.exitFromVault(self);
        }
        LaunchLogger(self.polylaunchSystem).logRefundModeInitiated(
            address(this)
        );
    }

    /**
     * @notice Refunds the user according to their token balance and NFT tappable balance
     * @param self Data struct associated with the launch
     * @param tokenId The specific venture bond that the refund is being claimed on
     */
    function claimRefund(LaunchUtils.Data storage self, uint256 tokenId)
        internal
        returns (uint256)
    {
        require(
            self.isRefundMode == true,
            "claimRefund: Launch is not in refund mode"
        );
        require(
            IERC721(self.ventureBondAddress).ownerOf(tokenId) == msg.sender,
            "claimRefund: Sender not ventureBond owner"
        );

        require(
            IVentureBond(self.ventureBondAddress).launchAddressAssociatedWithToken(tokenId) == address(this),
            "claimRefund: ventureBond not associated with this launch"
        );
        uint256 walletBalance = self.TOKEN.balanceOf(msg.sender);
        uint256 totalSenderBalance =
            IVentureBond(self.ventureBondAddress).tappableBalance(tokenId).add(
                walletBalance
            );
        uint256 bondVotingPower =
            IVentureBond(self.ventureBondAddress).votingPower(tokenId);

        uint256 refundableBalance =
            LaunchUtils.min(totalSenderBalance, bondVotingPower);
        uint256 amountDue =
            self.USD.balanceOf(address(this)).mul(refundableBalance).div(
                self.totalVotingPower
            );
        uint256 tappableBalance =
            IVentureBond(self.ventureBondAddress).tappableBalance(tokenId);
        
        if (totalSenderBalance > bondVotingPower) {
            self.TOKEN.safeTransferFrom(
                msg.sender,
                address(this),
                refundableBalance.sub(tappableBalance)
            );
            self.refundableTokens = self.refundableTokens.add(refundableBalance);
        } else {
            self.TOKEN.safeTransferFrom(
                msg.sender,
                address(this),
                walletBalance
            );
            self.refundableTokens = self.refundableTokens.add(refundableBalance);
        }

        self.totalVotingPower.sub(refundableBalance);
        IVentureBond(self.ventureBondAddress).updateVotingPower(
            tokenId,
            bondVotingPower - refundableBalance,
            msg.sender
        );
        if (tappableBalance != 0) {
            IVentureBond(self.ventureBondAddress).updateTappableBalance(
                tokenId,
                0,
                msg.sender
            );
        }

        self.USD.safeTransfer(msg.sender, amountDue);
        LaunchLogger(self.polylaunchSystem).logRefundClaimed(
            address(this),
            msg.sender,
            amountDue,
            tokenId
        );
        return amountDue;
    }

    /**
     * @notice increases the launcher fund tap
     * @param self Data struct associated with the launch
     * @param newRate new tap rate for launcher funds (wei/sec)
     */
    function increaseTap(LaunchUtils.Data storage self, uint256 newRate)
        public
    {
        LaunchRedemption.launcherTap(self);

        LaunchLogger(self.polylaunchSystem).logTapIncreased(
            address(this),
            self.launcherTapRate,
            newRate
        );
        self.launcherTapRate = newRate;
    }

    /**
     * @notice allows the launcher to claim back any refunded tokens
     * @param self Data struct associated with the launch
     */
    function launcherClaimRefund(LaunchUtils.Data storage self) internal {
        require(
            self.isRefundMode == true,
            "claimRefund: Launch is not in refund mode"
        );
        uint256 redeemable = self.refundableTokens;
        self.refundableTokens = 0;
        self.TOKEN.safeTransferFrom(
                address(this),
                msg.sender,
                redeemable
        );
    }
}
