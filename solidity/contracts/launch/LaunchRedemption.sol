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
import {VentureBondDataRegistry} from "../venture-nft/VentureBondDataRegistry.sol";

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
        require(self.launchSuccessful, "The launch was unsuccessful.");
        require(
            IERC721(self.ventureBondAddress).ownerOf(tokenId) == msg.sender,
            "You do not own the token you have attempted to tap from."
        );

        uint256 withdrawable =
            LaunchUtils.getSupporterWithdrawableFunds(self, tokenId);
        require(withdrawable > 0, "There are no funds to withdraw");

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
        require(self.END < block.timestamp, "The offering must be completed");
        require(
            self.totalFunding < self.MINIMUM_FUNDING,
            "The required amount has been provided!"
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
     * @notice Claim function for an supporter to either claim and mint their NFT for a successful launch or
     * retrieve their DAI after a failed launch
     * @param self Data struct associated with the launch
     */
    function claim(
        LaunchUtils.Data storage self,
        VentureBondDataRegistry.Register storage register
    ) internal {
        require(
            block.timestamp > self.END,
            "The offering has not finished yet"
        );
        require(
            self.provided[msg.sender] > 0,
            "You did not contribute to this offering"
        );

        if (block.timestamp > self.END && !self.launchSuccessful) {
            if (self.totalFunding > self.MINIMUM_FUNDING) {
                self.launchSuccessful = true;
            }
        }

        if (self.totalFunding >= self.MINIMUM_FUNDING) {
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
     */
    function _claimVentureBond(
        LaunchUtils.Data storage self,
        VentureBondDataRegistry.Register storage register
    ) private {
        require(
            self.launchSuccessful,
            "The minimum amount was not raised or the launch has not finished"
        );
        require(
            !self.nftRedeemed[msg.sender],
            "You have already claimed your control token"
        );
        uint256 userProvided = self.provided[msg.sender];
        uint256 tokenAmount =
            self.TOTAL_TOKENS_FOR_SALE.mul(userProvided).div(self.totalFunding);
        self.totalVotingPower += tokenAmount;
        uint256 tokenId = IVentureBond(self.ventureBondAddress).tokenIdCounter();
        IVentureBond.BaseNFTData memory _nftData = register.nftData[tokenId];
        // if the token launcher hasnt assigned data to this nft then mint a basic one with just the important data
        if (_nftData.contentHash == 0) {
            _nftData = IVentureBond.BaseNFTData({
                tokenURI: self.genericNftData.tokenURI,
                metadataURI: self.genericNftData.metadataURI,
                contentHash: self.genericNftData.contentHash,
                metadataHash: self.genericNftData.metadataHash
            });
        }
        IVentureBond.VentureBondData memory data =
            IVentureBond.VentureBondData({
                tokenURI: _nftData.tokenURI,
                metadataURI: _nftData.metadataURI,
                contentHash: _nftData.contentHash,
                metadataHash: _nftData.metadataHash,
                tapRate: self.supporterTapRate,
                lastWithdrawnTime: self.END,
                tappableBalance: tokenAmount,
                votingPower: tokenAmount
            });

        uint256 prevOwner = PolylaunchConstants.getPrevOwner();
        uint256 creator = PolylaunchConstants.getCreator();
        uint256 owner = PolylaunchConstants.getOwner();

        IMarket.BidShares memory shares =
            IMarket.BidShares({
                prevOwner: Decimal.D256(prevOwner),
                creator: Decimal.D256(creator),
                owner: Decimal.D256(owner)
            });
        self.nftRedeemed[msg.sender] = true;
        register.isNftMinted[tokenId] = true;
        IVentureBond(self.ventureBondAddress).mint(data, shares, msg.sender);
    }
}
