pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Decimal} from "../Decimal.sol";

import {LaunchUtils} from "./LaunchUtils.sol";
import {LaunchLogger} from "./LaunchLogger.sol";
import {IVentureBond} from "../../interfaces/IVentureBond.sol";
import {PolylaunchConstants} from "../system/PolylaunchConstants.sol";
import {IMarket} from "../../interfaces/IMarket.sol";
import {ILaunchFactory} from "../../interfaces/ILaunchFactory.sol";
import {PreLaunchRegistry} from "./PreLaunchRegistry.sol";

import "../../interfaces/IPolyVault.sol";
import "../../interfaces/ILaunchFactory.sol";

library LaunchRedemption {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    using LaunchUtils for LaunchUtils.Data;

    /**
     * @notice function to allow a launcher to tap the DAI that they are entitled to. Changes the lastWithdrawnTime
     * in the contract
     * @param self Data struct associated with the launch
     */
    function launcherTap(LaunchUtils.Data storage self) internal {
        if (block.timestamp > self.END && !self.launchSuccessful) {
            if (self.totalFunding > self.MINIMUM_FUNDING) {
                self.launchSuccessful = true;
            }
        }
        require(
            self.launchSuccessful,
            "The minimum amount was not raised or the launch has not finished"
        );
        if (self.yieldActivated) {
            address vaultRegistry =
                ILaunchFactory(self.launchFactory).getVaultRegistryAddress();
            IPolyVault(address(this))._launcherYieldTap(
                vaultRegistry,
                self.launcherTapRate,
                self.USD,
                self.fundRecipient,
                self.polylaunchSystem
            );
            self.lastWithdrawn = block.timestamp;
        } else {
            uint256 withdrawable = LaunchUtils.getLauncherWithdrawableFunds(self);
            require(withdrawable > 0, "There are no funds to withdraw");
            self.lastWithdrawn = block.timestamp;
            self.USD.safeTransfer(self.fundRecipient, withdrawable);

            LaunchLogger(self.polylaunchSystem).logLauncherFundsTapped(
                address(this),
                msg.sender,
                self.fundRecipient,
                withdrawable
            );
        }
    }


    /**
     * @notice function to allow an supporter to tap the tokens that they are entitled to. Changes the tappableBalance
     * and lastWithdrawnTime of the NFT provided
     * @param self Data struct associated with the launch
     * @param tokenId tokenId that the caller owns
     */
    function supporterTap(LaunchUtils.Data storage self, uint256 tokenId)
        internal
    {
        require(self.launchSuccessful, "Launch Unsuccessful.");
        require(
            IERC721(self.ventureBondAddress).ownerOf(tokenId) == msg.sender,
            "Not your ventureBond"
        );

        require(
            IVentureBond(self.ventureBondAddress).launchAddressAssociatedWithToken(tokenId) == address(this),
            "supporterTap: ventureBond not associated with this launch"
        );

        uint256 withdrawable =
            LaunchUtils.getSupporterWithdrawableFunds(self, tokenId);
        require(withdrawable > 0, "No funds to withdraw");

        uint256 tappableBalance =
            IVentureBond(self.ventureBondAddress).tappableBalance(tokenId);
        uint256 newTappableBalance = tappableBalance.sub(withdrawable);
        IVentureBond(self.ventureBondAddress).updateLastWithdrawnTime(
            tokenId,
            block.timestamp,
            msg.sender
        );
        IVentureBond(self.ventureBondAddress).updateTappableBalance(
            tokenId,
            newTappableBalance,
            msg.sender
        );
        //dealing with wei rounding errors for the last withdrawer
        uint256 tokenBalance_ = self.TOKEN.balanceOf(address(this));
        if ( tokenBalance_ < withdrawable){
            withdrawable = tokenBalance_;
        }
        self.TOKEN.safeTransfer(msg.sender, withdrawable);

        LaunchLogger(self.polylaunchSystem).logSupporterFundsTapped(
            address(this),
            msg.sender,
            tokenId,
            withdrawable,
            newTappableBalance
        );
    }

    /**
     * @notice Launcher can withdraw the tokens sent to the contract upon an unsuccessful launch
     * @param self Data struct associated with the launch
     */
    function withdrawTokenAfterFailedLaunch(LaunchUtils.Data storage self)
        internal
    {
        require(self.END < block.timestamp, "Launch not ended");
        require(
            self.totalFunding < self.MINIMUM_FUNDING,
            "Launch successful"
        );
        self.TOKEN.safeTransfer(
            msg.sender,
            self.TOKEN.balanceOf(address(this))
        );
        LaunchLogger(self.polylaunchSystem).logTokensWithdrawnAfterFailedLaunch(
            address(this)
        );
    }

    /**
     * @notice Launcher can withdraw the tokens sent to the contract that were not sold during the window
     * @param self Data struct associated with the launch
     */
    function withdrawUnsoldTokens(LaunchUtils.Data storage self)
        internal
    {
        require(self.END < block.timestamp, "The offering must be completed");
        uint256 soldTokens = (self.totalFunding.mul(self.FIXED_SWAP_RATE)).div(1e18);
        require(soldTokens < self.TOTAL_TOKENS_FOR_SALE, "All tokens sold");
        uint256 unsoldTokens = self.TOTAL_TOKENS_FOR_SALE.sub(soldTokens);
        self.TOKEN.safeTransfer(
            msg.sender,
            unsoldTokens
        );
        LaunchLogger(self.polylaunchSystem).logUnsoldTokensWithdrawn(
            address(this),
            unsoldTokens
        );
    }

    /**
     * @notice Claim function for an supporter to either claim and mint their NFT for a successful launch or
     * retrieve their DAI after a failed launch
     * @param self Data struct associated with the launch
     * @param register Register struct associated with the launch
     */
    function claim(
        LaunchUtils.Data storage self,
        PreLaunchRegistry.Register storage register
    ) internal {
        require(
            block.timestamp > self.END,
            "The offering has not finished"
        );
        require(
            self.provided[msg.sender] > 0,
            "msg.sender not eligible"
        );

        if (block.timestamp > self.END && !self.launchSuccessful) {
            if (self.totalFunding > self.MINIMUM_FUNDING) {
                self.launchSuccessful = true;
            }
        }

        if (self.launchSuccessful) {
            _claimVentureBond(self, register);
        } else {
            uint256 userProvided = self.provided[msg.sender];
            self.provided[msg.sender] = 0;
            self.USD.safeTransfer(msg.sender, userProvided);
            LaunchLogger(self.polylaunchSystem).logFundsWithdrawn(
                address(this),
                msg.sender,
                userProvided
            );
        }
    }


    /**
     * @notice Mints a Venture Bond token for the msg.sender, the tokenURI and metadataURI will need to be fixed later on
     * @param self Data struct associated with the launch
     * @param register Register struct associated with the launch
     */
    function _claimVentureBond(
        LaunchUtils.Data storage self,
        PreLaunchRegistry.Register storage register
    ) private {
        uint256 userProvided = self.provided[msg.sender];
        
        uint256 tokenAmount =
            (userProvided.mul(self.FIXED_SWAP_RATE)).div(1e18);
        self.totalVotingPower += tokenAmount;
        uint256 i = register.supporterIndex[msg.sender];
        IVentureBond.MediaData memory _nftData = register.nftData[i];
        // if the token launcher hasnt assigned data to this nft then mint a basic one with just the important data
        if (_nftData.metadataHash == 0) {
            _nftData = IVentureBond.MediaData({
                tokenURI: self.genericNftData.tokenURI,
                metadataHash: self.genericNftData.metadataHash
            });
        }
        IVentureBond.VentureBondParams memory vbParams =
            IVentureBond.VentureBondParams({
                tapRate: self.supporterTapRate,
                lastWithdrawnTime: self.END,
                tappableBalance: tokenAmount,
                votingPower: tokenAmount
            });
        delete self.provided[msg.sender];
        delete register.nftData[i];
        register.isIndexMinted[i] = true;
        IVentureBond(self.ventureBondAddress).mint(msg.sender, _nftData, vbParams);
    }
}
