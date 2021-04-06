// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Decimal} from "../Decimal.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../venture-nft/VentureBond.sol";
import "../venture-nft/Market.sol";
import "../../interfaces/IVentureBond.sol";
import "../../interfaces/IMarket.sol";
import "../../interfaces/ICErc20.sol";
import "../system/PolylaunchConstants.sol";
import "../venture-nft/VentureBondDataRegistry.sol";

/**
 * @author PolyLaunch Protocol
 * @title Launch Utils
 * @notice Library containing functions that are handled the same way among all types of launches.
 */

library LaunchUtils {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Data {
        // whether a launch is initialised
        bool initialised;
        // contract for dai/usd (accepted investment currency)
        IERC20 USD;
        // contract for token being sold
        IERC20 TOKEN;
        // start date for the launch
        uint256 START;
        // end date for the launch
        uint256 END;
        // number of tokens being sold
        uint256 TOTAL_TOKENS_FOR_SALE;
        // minimum funding required for a successful launch
        uint256 MINIMUM_FUNDING;
        // total amount of funding a launch can receive
        uint256 FUNDING_CAP;
        // launcher tap rate (wei/sec)
        uint256 launcherTapRate;
        // supporter tap rate (wei/sec)
        uint256 supporterTapRate;
        // launcher who will receive USD funds
        address fundRecipient;
        // mapping to hold the amount an address has provided to the launch in DAI
        mapping(address => uint256) provided;
        // total funding a launch has received
        uint256 totalFunding;
        // the last time a launcher tapped their funds
        uint256 lastWithdrawn;
        // launcher
        address launcher;
        // factory that deployed the launch
        address launchFactory;
        // whether the launch was successful
        bool launchSuccessful;
        // Venture Bond address associated with the launch
        address ventureBondAddress;
        // Market address associated with the launch
        address marketAddress;
        // Governor addresss
        address governor;
        // Total voting power available in the launch
        uint256 totalVotingPower;
        // mapping for whether an address has redeemed their NFT or not
        mapping(address => bool) nftRedeemed;
        // generic nft Data
        IVentureBond.BaseNFTData genericNftData;
        // is yield on launcher funds activated
        bool yieldActivated;
        // is the contract in refund mode
        bool isRefundMode;
        // polylaunch system address
        address polylaunchSystem;
    }

    /**
     * @notice Get the launcher's withdrawable funds from the contract
     * @param self Data struct associated with the launch
     * @return the withdrawable funds of the launcher
     * @dev need to work this out properly
     */
    function getLauncherWithdrawableFunds(Data storage self)
        internal
        view
        returns (uint256)
    {
        if (!self.launchSuccessful) {
            return 0;
        }
        uint256 usdBalance = self.USD.balanceOf(address(this));
        uint256 withdrawable =
            self.launcherTapRate.mul(block.timestamp.sub(self.lastWithdrawn));

        if (usdBalance < withdrawable) {
            withdrawable = usdBalance;
        }
        return withdrawable;
    }

    /**
     * @notice Get the supporters withdrawable funds from the NFT, requires a tokenId owned by the claimant
     * @param self Data struct associated with the launch
     * @param tokenId token that the caller owns
     * @return the withdrawable funds of the NFT provided
     */
    function getSupporterWithdrawableFunds(Data storage self, uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        if (!self.launchSuccessful) {
            return 0;
        }
        uint256 tapRate = IVentureBond(self.ventureBondAddress).tapRate(tokenId);
        uint256 lastWithdrawnTime =
            IVentureBond(self.ventureBondAddress).lastWithdrawnTime(tokenId);
        uint256 tappableBalance =
            IVentureBond(self.ventureBondAddress).tappableBalance(tokenId);
        uint256 withdrawable =
            tapRate.mul(block.timestamp.sub(lastWithdrawnTime));

        if (tappableBalance < withdrawable) {
            withdrawable = tappableBalance;
        }
        return withdrawable;
    }

    /**
     * @notice return the amount of funds provided to a launch
     * @param self Data struct associated with the launch
     * @return the amount of funds provided to a launch
     */
    function totalFundsProvided(Data storage self)
        internal
        view
        returns (uint256)
    {
        return self.totalFunding;
    }

    /**
     * @notice return the funds provided by an address
     * @param self Data struct associated with the launch
     * @param addr the address to be checked
     * @return the funds (DAI) provided by the address
     */
    function fundsProvidedByAddress(Data storage self, address addr)
        internal
        view
        returns (uint256)
    {
        return self.provided[addr];
    }

    /**
     * @notice return the start time of the launch
     * @param self Data struct associated with the launch
     * @return the start time of the launch
     */
    function launchStartTime(Data storage self) internal view returns (uint256) {
        return self.START;
    }

    /**
     * @notice return the end time of the launch
     * @param self Data struct associated with the launch
     * @return the end time of the launch
     */
    function launchEndTime(Data storage self) internal view returns (uint256) {
        return self.END;
    }

    /**
     * @notice return the contract for the token being sold in the launch
     * @param self Data struct associated with the launch
     * @return the token contract for the token being sold
     */
    function tokenForLaunch(Data storage self) internal view returns (IERC20) {
        return self.TOKEN;
    }

    /**
     * @notice return the VentureBond address associated with the launch
     * @param self Data struct associated with the launch
     * @return the VentureBond address associated with the launch
     */
    function launchVentureBondAddress(Data storage self)
        internal
        view
        returns (address)
    {
        return self.ventureBondAddress;
    }

    /**
     * @notice return the market address associated with the launch
     * @param self Data struct associated with the launch
     * @return the market address associated with the launch
     */
    function launchMarketAddress(Data storage self)
        internal
        view
        returns (address)
    {
        return self.marketAddress;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
