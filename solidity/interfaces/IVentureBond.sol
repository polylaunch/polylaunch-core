// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import {IMarket} from "./IMarket.sol";

/**
 * @title Interface for Zora Protocol's Media
 */
interface IVentureBond {


    struct MediaData {
        // A valid URI of the content represented by this token
        string tokenURI;
        // A SHA256 hash of the content pointed to by metadataURI
        bytes32 metadataHash;
    }

    struct VentureBondParams {
        uint256 tapRate;
        uint256 lastWithdrawnTime;
        uint256 tappableBalance;
        uint256 votingPower;
    }
    
    /**
     * @notice Mint new media for msg.sender.
     */
    function mint(
        address owner, 
        MediaData calldata data, 
        IMarket.BidShares calldata bidShares, 
        VentureBondParams calldata ventureBondParams
        )
        external;

    /**
     * @notice Transfer the token with the given ID to a given address.
     * Save the previous owner before the transfer, in case there is a sell-on fee.
     * @dev This can only be called by the auction contract specified at deployment
     */
    function auctionTransfer(uint256 tokenId, address recipient) external;

    /**
     * @notice Set the ask on a piece of media
     */
    function setAsk(uint256 tokenId, IMarket.Ask calldata ask) external;

    /**
     * @notice Remove the ask on a piece of media
     */
    function removeAsk(uint256 tokenId) external;

    /**
     * @notice Set the bid on a piece of media
     */
    function setBid(uint256 tokenId, IMarket.Bid calldata bid) external;

    /**
     * @notice Remove the bid on a piece of media
     */
    function removeBid(uint256 tokenId) external;

    function acceptBid(uint256 tokenId, IMarket.Bid calldata bid) external;

    /**
     * @notice Return the tapRate for a VentureBond given the token URI
     */
    function tapRate(uint256 tokenId)
        external
        view
        returns (uint256);

    /**
     * @notice Return the lastWithdrawnTime of a VentureBond given the token URI
     */
    function lastWithdrawnTime(uint256 tokenId)
        external
        view
        returns (uint256);

    /**
     * @notice Return the tappableBalance VentureBond given the token URI
     */
    function tappableBalance(uint256 tokenId)
        external
        view
        returns (uint256);

    /**
     * @notice Return the tappableBalance VentureBond given the token URI
     */
    function votingPower(uint256 tokenId)
        external
        view
        returns (uint256);

    /**
     * @notice Update the tap rate
     */
    function updateTapRate(uint256 tokenId, uint256 _tapRate, address _owner) external;

    /**
     * @notice Update the lastWithdrawnTime
     */
    function updateLastWithdrawnTime(uint256 tokenId, uint256 _lastWithdrawnTime, address _owner) external;

    /**
     * @notice Update the tappable balance
     */
    function updateTappableBalance(uint256 tokenId, uint256 _tappableBalance, address _owner) external;

    /**
     * @notice Update the tappable balance
     */
    function updateVotingPower(uint256 tokenId, uint256 _votingPower, address _owner) external;

    function authoriseLaunch(address launch) external;

    function launchAddressAssociatedWithToken(uint256 tokenId) external view returns (address);
}