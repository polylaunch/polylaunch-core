pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import {IMarket} from "./IMarket.sol";

/**
 * @title Interface for VentureBond
 */
interface IVentureBond {
//    struct EIP712Signature {
//        uint256 deadline;
//        uint8 v;
//        bytes32 r;
//        bytes32 s;
//    }

    struct VentureBondData {
        // A valid URI of the content represented by this token
        string tokenURI;
        // A valid URI of the metadata associated with this token
        string metadataURI;
        // A SHA256 hash of the content pointed to by tokenURI
        bytes32 contentHash;
        // A SHA256 hash of the content pointed to by metadataURI
        bytes32 metadataHash;
        // The configured tapRate of the NFT representing the wei/sec the owner is eligible for
        uint256 tapRate;
        // The configured lastWithdrawnTime of the NFT, represent the last time a user withdrew funds
        uint256 lastWithdrawnTime;
        // The balance of the ERC20 token that the owner of the NFT started with
        uint256 tappableBalance;
        // The voting power of the NFT
        uint256 votingPower;
    }

    // struct used for the data registry
    struct BaseNFTData {
        // A valid URI of the content represented by this token
        string tokenURI;
        // A valid URI of the metadata associated with this token
        string metadataURI;
        // A SHA256 hash of the content pointed to by tokenURI
        bytes32 contentHash;
        // A SHA256 hash of the content pointed to by metadataURI
        bytes32 metadataHash;
    }

    event TokenURIUpdated(uint256 indexed _tokenId, address owner, string _uri);
    event TokenMetadataURIUpdated(uint256 indexed _tokenId, address owner, string _uri);
    event TapRateUpdated(uint256 indexed _tokenID, address owner, uint256 _tapRate);
    event LastWithdrawnTimeUpdated(uint256 indexed _tokenID, address owner, uint256 _lastWithdrawnTime);
    event TappableBalanceUpdated(uint256 indexed _tokenID, address owner, uint256 _tappableBalance);
    event TokenMinted(address indexed _owner, uint256 _tokenId, uint256 _tappableBalance);

    /**
     * @notice Return the metadata URI for a VentureBond given the token URI
     */
    function tokenIdCounter()
        external
        view
        returns (uint256);
    /**
     * @notice Return the metadata URI for a VentureBond given the token URI
     */
    function tokenMetadataURI(uint256 tokenId)
        external
        view
        returns (string memory);

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
     * @notice Mint new VentureBond for msg.sender.
     */
    function mint(VentureBondData calldata data, IMarket.BidShares calldata bidShares, address owner)
        external;

//    /**
//     * @notice EIP-712 mintWithSig method. Mints new VentureBond for a creator given a valid signature.
//     */
//    function mintWithSig(
//        address creator,
//        VentureBondData calldata data,
//        IMarket.BidShares calldata bidShares,
//        EIP712Signature calldata sig
//    ) external;

    /**
     * @notice Transfer the token with the given ID to a given address.
     * Save the previous owner before the transfer, in case there is a sell-on fee.
     * @dev This can only be called by the auction contract specified at deployment
     */
    function auctionTransfer(uint256 tokenId, address recipient) external;

    /**
     * @notice Set the ask on a piece of VentureBond
     */
    function setAsk(uint256 tokenId, IMarket.Ask calldata ask) external;

    /**
     * @notice Remove the ask on a piece of VentureBond
     */
    function removeAsk(uint256 tokenId) external;

    /**
     * @notice Set the bid on a piece of VentureBond
     */
    function setBid(uint256 tokenId, IMarket.Bid calldata bid) external;

    /**
     * @notice Remove the bid on a piece of VentureBond
     */
    function removeBid(uint256 tokenId) external;

    function acceptBid(uint256 tokenId, IMarket.Bid calldata bid) external;

    /**
     * @notice Revoke approval for a piece of VentureBond
     */
    function revokeApproval(uint256 tokenId) external;

    /**
     * @notice Update the token URI
     */
    function updateTokenURI(uint256 tokenId, string calldata tokenURI, address owner) external;

    /**
     * @notice Update the token metadata uri
     */
    function updateTokenMetadataURI(
        uint256 tokenId,
        string calldata metadataURI,
        address owner
    ) external;

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

//    /**
//     * @notice EIP-712 permit method. Sets an approved spender given a valid signature.
//     */
//    function permit(
//        address spender,
//        uint256 tokenId,
//        EIP712Signature calldata sig
//    ) external;
}