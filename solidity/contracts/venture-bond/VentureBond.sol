// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Decimal} from "../Decimal.sol";
import {IMarket} from "../../interfaces/IMarket.sol";
import "../../interfaces/IVentureBond.sol";

/**
 * @title A media value system, with perpetual equity to creators
 * @notice This contract provides an interface to mint media with a market
 * owned by the creator.
 */
contract VentureBond is ERC721, IVentureBond, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    /* *******
     * Globals
     * *******
     */

    // Address for the market
    address public marketContract;

    // Address for the system
    address public systemContract;

    // Address for the factory
    address public factoryContract;

    // Mapping from token to previous owner of the token
    mapping(uint256 => address) public previousTokenOwners;

    // Mapping from tokenId to its corresponding launch address
    mapping(uint256 => address) public tokenAssociatedLaunch; 

    // Mapping from token id to creator address
    mapping(uint256 => address) public tokenCreators;

    // Mapping from token id to sha256 hash of metadata
    mapping(uint256 => bytes32) public tokenMetadataHashes;

    // Mapping from token id to venture bond parameters
    mapping(uint256 => VentureBondParams) public tokenVentureBondParams;

    // Mapping to track launches that are allowed to mint venture bonds
    mapping(address => bool) public isAuthorisedLaunch;

    Counters.Counter private tokenIdTracker;

    /* *********
     * Modifiers
     * *********
     */

    /**
     * @notice Require that the token has not been burned and has been minted
     */
    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "Media: nonexistent token");
        _;
    }


    /**
     * @notice Require that the token has had a metadata hash set
     */
    modifier onlyTokenWithMetadataHash(uint256 tokenId) {
        require(
            tokenMetadataHashes[tokenId] != 0,
            "Media: token does not have hash of its metadata"
        );
        _;
    }


    /**
     * @notice Require that the sender is the factory
     */
    modifier onlyFactory() {
        require(
            msg.sender == factoryContract,
            "VentureBond: not the factory"
        );
        _;
    }

    /**
     * @notice Require that the sender is the factory
     */
    modifier onlyAuthorised() {
        require(
            isAuthorisedLaunch[msg.sender],
            "VentureBond: not an Authorised launch"
        );
        _;
    }

    modifier onlyAssociatedToken(uint256 tokenId) {
        require(
            tokenAssociatedLaunch[tokenId] == msg.sender,
            "VentureBond: msg.sender is not the associated launch to this token"
        );
        _; 
    }


    /**
     * @notice Ensure that the provided spender is the approved or the owner of
     * the media for the specified tokenId
     */
    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "Media: Only approved or owner"
        );
        _;
    }

    /**
     * @notice Ensure the token has been created (even if it has been burned)
     */
    modifier onlyTokenCreated(uint256 tokenId) {
        require(
            tokenIdTracker.current() > tokenId,
            "Media: token with that id does not exist"
        );
        _;
    }

    /**
     * @notice Ensure that the provided URI is not empty
     */
    modifier onlyValidURI(string memory uri) {
        require(
            bytes(uri).length != 0,
            "Media: specified uri must be non-empty"
        );
        _;
    }

    /**
     * @notice On deployment, set the market contract address system contract and factory contract
     * ERC721 metadata interface
     */
    constructor(address marketContractAddr, address systemContractAddr, address factoryContractAddr) public ERC721("Polylaunch", "POLYLAUNCH") {
        marketContract = marketContractAddr;
        systemContract = systemContractAddr;
        factoryContract = factoryContractAddr;
    }

    /* **************
     * View Functions
     * **************
     */


    /**
     * @notice Return the tapRate for a VentureBond given the token URI
     * @return the tapRate for the token
     */
    function tapRate(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (uint256)
    {
        return tokenVentureBondParams[tokenId].tapRate;
    }

    /**
     * @notice Return the last withdrawn time for a VentureBond given the token URI
     * @return the last withdrawn time for the token
     */
    function lastWithdrawnTime(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (uint256)
    {
        return tokenVentureBondParams[tokenId].lastWithdrawnTime;
    }

    /**
     * @notice Return the tappable balance for a VentureBond given the token id
     * @return the tappable balance for the token
     */
    function tappableBalance(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (uint256)
    {
        return tokenVentureBondParams[tokenId].tappableBalance;
    }

    /**
     * @notice Return the voting power for a VentureBond given the token id
     * @return the voting power for the token
     */
    function votingPower(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (uint256)
    {
        return tokenVentureBondParams[tokenId].votingPower;
    }

    function launchAddressAssociatedWithToken(uint256 tokenId)
    external 
    view
    override
    onlyTokenCreated(tokenId) 
    returns (address) {
        return tokenAssociatedLaunch[tokenId];
    }

    /* ****************
     * Public Functions
     * ****************
     */

    /**
     * @notice see IMedia
     */
    function mint(
        address owner, 
        MediaData memory data, 
        IMarket.BidShares memory bidShares, 
        VentureBondParams memory ventureBondParams
        )
        public
        override
        nonReentrant
        onlyAuthorised
    {
        _mintForCreator(owner, data, bidShares, ventureBondParams);
    }


    function authoriseLaunch(address launch) external override onlyFactory {
        isAuthorisedLaunch[launch] = true;
    }

    /* ****************
     * Market Functions
     * ****************
     */

    /**
     * @notice see IMedia
     */
    function auctionTransfer(uint256 tokenId, address recipient)
        external
        override
    {
        require(msg.sender == marketContract, "Media: only market contract");
        previousTokenOwners[tokenId] = ownerOf(tokenId);
        _safeTransfer(ownerOf(tokenId), recipient, tokenId, "");
    }

    /**
     * @notice see IMedia
     */
    function setAsk(uint256 tokenId, IMarket.Ask memory ask)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).setAsk(tokenId, ask);
    }

    /**
     * @notice see IMedia
     */
    function removeAsk(uint256 tokenId)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).removeAsk(tokenId);
    }

    /**
     * @notice see IMedia
     */
    function setBid(uint256 tokenId, IMarket.Bid memory bid)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
    {
        require(msg.sender == bid.bidder, "Market: Bidder must be msg sender");
        IMarket(marketContract).setBid(tokenId, bid, msg.sender);
    }

    /**
     * @notice see IMedia
     */
    function removeBid(uint256 tokenId)
        external
        override
        nonReentrant
        onlyTokenCreated(tokenId)
    {
        IMarket(marketContract).removeBid(tokenId, msg.sender);
    }

    /**
     * @notice see IMedia
     */
    function acceptBid(uint256 tokenId, IMarket.Bid memory bid)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).acceptBid(tokenId, bid);
    }

    /* ****************
     * Venture Bond Functions
     * ****************
     */

    /*
     * @notice see IVentureBond
     * @dev only callable by launch contract
     */
    function updateTapRate(
        uint256 tokenId,
        uint256 _tapRate,
        address _owner
    )
        external
        override
        onlyApprovedOrOwner(_owner, tokenId)
        onlyAuthorised
        onlyAssociatedToken(tokenId)
    {
        _setTapRate(tokenId, _tapRate);
    }

    /*
     * @notice see IVentureBond
     * @dev only callable by launch contract
     */
    function updateLastWithdrawnTime(
        uint256 tokenId,
        uint256 _lastWithdrawnTime,
        address _owner
    )
        external
        override
        onlyApprovedOrOwner(_owner, tokenId)
        onlyAuthorised
        onlyAssociatedToken(tokenId)
    {
        _setLastWithdrawnTime(tokenId, _lastWithdrawnTime);
    }

    /*
     * @notice see IVentureBond
     * @dev only callable by launch contract or governer contract
     */
    function updateTappableBalance(
        uint256 tokenId,
        uint256 _tappableBalance,
        address _owner
    )
        external
        override
        onlyApprovedOrOwner(_owner, tokenId)
        onlyAuthorised
        onlyAssociatedToken(tokenId)
    {
        _setTappableBalance(tokenId, _tappableBalance);
    }

    /*
     * @notice see IVentureBond
     * @dev only callable by launch contract
     */
    function updateVotingPower(
        uint256 tokenId,
        uint256 _votingPower,
        address _owner
    )
        external
        override
        onlyApprovedOrOwner(_owner, tokenId)
        onlyAuthorised
        onlyAssociatedToken(tokenId)
    {
        _setVotingPower(tokenId, _votingPower);
    }
    /* *****************
     * Private Functions
     * *****************
     */

    /**
     * @notice Creates a new token for `creator`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_safeMint}.
     *
     * On mint, also set the sha256 hashes of the content and its metadata for integrity
     * checks, along with the initial URIs to point to the content and metadata. Attribute
     * the token ID to the creator, mark the content hash as used, and set the bid shares for
     * the media's market.
     *
     * Note that although the content hash must be unique for future mints to prevent duplicate media,
     * metadata has no such requirement.
     */
    function _mintForCreator(
        address creator,
        MediaData memory data,
        IMarket.BidShares memory bidShares,
        VentureBondParams memory ventureBondParams
    ) internal onlyValidURI(data.tokenURI){
        require(
            data.metadataHash != 0,
            "Media: metadata hash must be non-zero"
        );

        uint256 tokenId = tokenIdTracker.current();

        _safeMint(creator, tokenId);
        tokenIdTracker.increment();
        _setTokenMetadataHash(tokenId, data.metadataHash);
        _setTokenURI(tokenId, data.tokenURI);
        tokenVentureBondParams[tokenId] = ventureBondParams;
        tokenAssociatedLaunch[tokenId] = msg.sender;

        tokenCreators[tokenId] = systemContract;
        previousTokenOwners[tokenId] = creator;
        IMarket(marketContract).setBidShares(tokenId, bidShares);
    }


    function _setTokenMetadataHash(uint256 tokenId, bytes32 metadataHash)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenMetadataHashes[tokenId] = metadataHash;
    }

    function _setTapRate(uint256 tokenId, uint256 _tapRate)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenVentureBondParams[tokenId].tapRate = _tapRate;
    }

    function _setLastWithdrawnTime(uint256 tokenId, uint256 _lastWithdrawnTime)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenVentureBondParams[tokenId].lastWithdrawnTime = _lastWithdrawnTime;
    }

    function _setTappableBalance(uint256 tokenId, uint256 _tappableBalance)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenVentureBondParams[tokenId].tappableBalance = _tappableBalance;
    }

    function _setVotingPower(uint256 tokenId, uint256 _votingPower)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenVentureBondParams[tokenId].votingPower = _votingPower;
    }


    /**
     * @notice transfer a token and remove the ask for it.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        IMarket(marketContract).removeAsk(tokenId);

        super._transfer(from, to, tokenId);
    }

}