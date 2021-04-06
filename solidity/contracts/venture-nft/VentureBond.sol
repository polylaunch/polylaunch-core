pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import {ERC721Burnable} from "../venture-nft/ERC721Burnable.sol";
import {ERC721} from "../venture-nft/ERC721.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
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
 * @title A tradable tap access control token system, with perpetual equity to creators
 * @notice This contract provides an interface to mint a venture bond with a market
 * owned by the creator, market to be modified.
 */
contract VentureBond is IVentureBond, ERC721Burnable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    /* *******
     * Globals
     * *******
     */

    // Address for the market
    address public marketContract;
    // Address for the market
    address public launchContract;
    // Deployment Address
    address public deployer;

    // Mapping from token to previous owner of the token
    mapping(uint256 => address) public previousTokenOwners;

    // Mapping from token id to creator address
    mapping(uint256 => address) public tokenCreators;

    // Mapping from creator address to their (enumerable) set of created tokens
    mapping(address => EnumerableSet.UintSet) private _creatorTokens;

    // Mapping from token id to sha256 hash of content
    mapping(uint256 => bytes32) public tokenContentHashes;

    // Mapping from token id to sha256 hash of metadata
    mapping(uint256 => bytes32) public tokenMetadataHashes;

    // Mapping from token id to metadataURI
    mapping(uint256 => string) private _tokenMetadataURIs;

    // Mapping from token id to tapRate
    mapping(uint256 => uint256) private _tokenTapRates;

    // Mapping from token id to lastWithdrawnTime
    mapping(uint256 => uint256) private _tokenLastWithdrawnTimes;

    // Mapping from token id to tappableBalance
    mapping(uint256 => uint256) private _tokenTappableBalances;

    // Mapping from token id to votingPower
    mapping(uint256 => uint256) private _tokenVotingPowers;

    // Mapping from contentHash to bool
    mapping(bytes32 => bool) private _contentHashes;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *     bytes4(keccak256('tokenMetadataURI(uint256)')) == 0x157c3df9
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd ^ 0x157c3df9 == 0x4e222e66
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x4e222e66;

    Counters.Counter public _tokenIdTracker;

    /* *********
     * Modifiers
     * *********
     */

    /**
     * @notice Require that the token has not been burned and has been minted
     */
    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "VentureBond: nonexistent token");
        _;
    }

    /**
     * @notice Require that the token has had a content hash set
     */
    modifier onlyTokenWithContentHash(uint256 tokenId) {
        require(
            tokenContentHashes[tokenId] != 0,
            "VentureBond: token does not have hash of created content"
        );
        _;
    }

    /**
     * @notice Require that the token has had a metadata hash set
     */
    modifier onlyTokenWithMetadataHash(uint256 tokenId) {
        require(
            tokenMetadataHashes[tokenId] != 0,
            "VentureBond: token does not have hash of its metadata"
        );
        _;
    }

    /**
     * @notice Require that the token has had a tap rate set
     */
    modifier onlyTokenWithTapRate(uint256 tokenId) {
        require(
            _tokenTapRates[tokenId] != 0,
            "VentureBond: token does not have a tap rate or tap rate is 0"
        );
        _;
    }

    /**
     * @notice Require that the token has had lastWithdrawnTime set / can vote
     */
    modifier onlyTokenWithLastWithdrawnTime(uint256 tokenId) {
        require(
            _tokenLastWithdrawnTimes[tokenId] != 0,
            "VentureBond: token does not have a last withdrawn time"
        );
        _;
    }

    /**
     * @notice Require that the token has had a tappable balance set
     */
    modifier onlyTokenWithTappableBalance(uint256 tokenId) {
        require(
            _tokenTappableBalances[tokenId] != 0,
            "VentureBond: token does not have a tappable balance"
        );
        _;
    }

    /**
     * @notice Require that the token has had a voting power set
     */
    modifier onlyTokenWithVotingPower(uint256 tokenId) {
        require(
            _tokenVotingPowers[tokenId] != 0,
            "VentureBond: token does not have any voting Power"
        );
        _;
    }

    /**
     * @notice require that the msg.sender is the configured basic launch contract
     */
    modifier onlyLaunchCaller() {
        require(launchContract == msg.sender, "VentureBond: Only launch contract");
        _;
    }
    /**
     * @notice Ensure that the provided spender is the approved or the owner of
     * the VentureBond for the specified tokenId
     */
    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "VentureBond: Only approved or owner"
        );
        _;
    }

    /**
     * @notice Ensure the token has been created (even if it has been burned)
     */
    modifier onlyTokenCreated(uint256 tokenId) {
        require(
            _tokenIdTracker.current() > tokenId,
            "VentureBond: token with that id does not exist"
        );
        _;
    }

    /**
     * @notice Ensure that the provided URI is not empty
     */
    modifier onlyValidURI(string memory uri) {
        require(
            bytes(uri).length != 0,
            "VentureBond: specified uri must be non-empty"
        );
        _;
    }

    /**
     * @notice On deployment from the factory, set the market contract address and register the
     * ERC721 metadata interface
     */
    constructor(
        address marketContractAddr,
        address launchContractAddr,
        string memory _name,
        string memory _symbol,
        address polylaunchSystemAddress
    ) public ERC721(_name, _symbol) {
        marketContract = marketContractAddr;
        launchContract = launchContractAddr;
        deployer = polylaunchSystemAddress;
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
    }

    /* **************
     * View Functions
     * **************
     */

    /**
     * @notice return the current counter number
     * @return the tokenId of the next token
     */
    function tokenIdCounter() public view override returns (uint256) {
        return _tokenIdTracker.current();
    }

    /**
     * @notice return the URI for a particular VentureBond with the specified tokenId
     * @dev This function is an override of the base OZ implementation because we
     * will return the tokenURI even if the VentureBond has been burned. In addition, this
     * protocol does not support a base URI, so relevant conditionals are removed.
     * @return the URI for a token
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        onlyTokenCreated(tokenId)
        returns (string memory)
    {
        string memory _tokenURI = _tokenURIs[tokenId];

        return _tokenURI;
    }

    /**
     * @notice Return the metadata URI for a VentureBond given the token URI
     * @return the metadata URI for the token
     */
    function tokenMetadataURI(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (string memory)
    {
        return _tokenMetadataURIs[tokenId];
    }

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
        return _tokenTapRates[tokenId];
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
        return _tokenLastWithdrawnTimes[tokenId];
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
        return _tokenTappableBalances[tokenId];
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
        return _tokenVotingPowers[tokenId];
    }

    /* ****************
     * Public Functions
     * ****************
     */

    /**
     * @notice see IVentureBond
     */
    function mint(
        VentureBondData memory data,
        IMarket.BidShares memory bidShares,
        address _owner
    ) public override nonReentrant onlyLaunchCaller {
        _mintForCreator(_owner, data, bidShares);
    }

    /**
     * @notice see IVentureBond
     */
    function auctionTransfer(uint256 tokenId, address recipient)
        external
        override
    {
        require(msg.sender == marketContract, "VentureBond: only market contract");
        previousTokenOwners[tokenId] = ownerOf(tokenId);
        _safeTransfer(ownerOf(tokenId), recipient, tokenId, "");
    }

    /**
     * @notice see IVentureBond
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
     * @notice see IVentureBond
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
     * @notice see IVentureBond
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
     * @notice see IVentureBond
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
     * @notice see IVentureBond
     */
    function acceptBid(uint256 tokenId, IMarket.Bid memory bid)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).acceptBid(tokenId, bid);
    }

    /**
     * @notice Burn a token.
     * @dev Only callable if the VentureBond owner is also the creator.
     */
    function burn(uint256 tokenId)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        address owner = ownerOf(tokenId);

        require(
            tokenCreators[tokenId] == owner,
            "VentureBond: owner is not creator of the VentureBond"
        );

        _burn(tokenId);
    }

    /**
     * @notice Revoke the approvals for a token. The provided `approve` function is not sufficient
     * for this protocol, as it does not allow an approved address to revoke it's own approval.
     * In instances where a 3rd party is interacting on a user's behalf via `permit`, they should
     * revoke their approval once their task is complete as a best practice.
     */
    function revokeApproval(uint256 tokenId) external override nonReentrant {
        require(
            msg.sender == getApproved(tokenId),
            "VentureBond: caller not approved address"
        );
        _approve(address(0), tokenId);
    }

    /**
     * @notice see IVentureBond
     * @dev only callable by launch contract
     * @dev relies on custom ERC721
     */
    function updateTokenURI(
        uint256 tokenId,
        string calldata _tokenURI,
        address _owner
    )
        external
        override
        nonReentrant
        onlyApprovedOrOwner(_owner, tokenId)
        onlyTokenWithContentHash(tokenId)
        onlyValidURI(_tokenURI)
        onlyLaunchCaller
    {
        _setTokenURI(tokenId, _tokenURI);
        emit TokenURIUpdated(tokenId, msg.sender, _tokenURI);
    }

    /*
     * @notice see IVentureBond
     * @dev only callable by launch contract
     */
    function updateTokenMetadataURI(
        uint256 tokenId,
        string calldata _metadataURI,
        address _owner
    )
        external
        override
        nonReentrant
        onlyApprovedOrOwner(_owner, tokenId)
        onlyTokenWithMetadataHash(tokenId)
        onlyValidURI(_metadataURI)
        onlyLaunchCaller
    {
        _setTokenMetadataURI(tokenId, _metadataURI);
        emit TokenMetadataURIUpdated(tokenId, msg.sender, _metadataURI);
    }

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
        nonReentrant
        onlyApprovedOrOwner(_owner, tokenId)
        onlyTokenWithTapRate(tokenId)
        onlyLaunchCaller
    {
        _setTapRate(tokenId, _tapRate);
        emit TapRateUpdated(tokenId, msg.sender, _tapRate);
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
        nonReentrant
        onlyApprovedOrOwner(_owner, tokenId)
        onlyTokenWithLastWithdrawnTime(tokenId)
        onlyLaunchCaller
    {
        _setLastWithdrawnTime(tokenId, _lastWithdrawnTime);
        emit LastWithdrawnTimeUpdated(tokenId, msg.sender, _lastWithdrawnTime);
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
        nonReentrant
        onlyApprovedOrOwner(_owner, tokenId)
        onlyTokenWithTappableBalance(tokenId)
        onlyLaunchCaller
    {
        _setTappableBalance(tokenId, _tappableBalance);
        emit TappableBalanceUpdated(tokenId, msg.sender, _tappableBalance);
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
        nonReentrant
        onlyApprovedOrOwner(_owner, tokenId)
        onlyTokenWithVotingPower(tokenId)
        onlyLaunchCaller
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
     * See {ERC721-_safeMint}.
     *
     * On mint, also set the sha256 hashes of the content and its metadata for integrity
     * checks, along with the initial URIs to point to the content and metadata. Attribute
     * the token ID to the creator, mark the content hash as used, and set the bid shares for
     * the VentureBond's market.
     *
     * Note that although the content hash must be unique for future mints to prevent duplicate VentureBonds,
     * metadata has no such requirement.
     */
    function _mintForCreator(
        address creator,
        VentureBondData memory data,
        IMarket.BidShares memory bidShares
    ) internal onlyValidURI(data.tokenURI) onlyValidURI(data.metadataURI) {
        require(
            data.contentHash != 0,
            "VentureBond: content hash must be non-zero"
        );
        //        require(
        //            _contentHashes[data.contentHash] == false,
        //            "VentureBond: a token has already been created with this content hash"
        //        );
        require(
            data.metadataHash != 0,
            "VentureBond: metadata hash must be non-zero"
        );

        uint256 tokenId = _tokenIdTracker.current();

        _safeMint(creator, tokenId);
        _tokenIdTracker.increment();
        _setTokenContentHash(tokenId, data.contentHash);
        _setTokenMetadataHash(tokenId, data.metadataHash);
        _setTokenMetadataURI(tokenId, data.metadataURI);
        _setTokenURI(tokenId, data.tokenURI);
        _setTapRate(tokenId, data.tapRate);
        _setLastWithdrawnTime(tokenId, data.lastWithdrawnTime);
        _setTappableBalance(tokenId, data.tappableBalance);
        _setVotingPower(tokenId, data.votingPower);
        _creatorTokens[creator].add(tokenId);
        _contentHashes[data.contentHash] = true;

        tokenCreators[tokenId] = deployer;
        previousTokenOwners[tokenId] = deployer;
        IMarket(marketContract).setBidShares(tokenId, bidShares);
        emit TokenMinted(creator, tokenId, data.tappableBalance);
    }

    function _setTokenContentHash(uint256 tokenId, bytes32 contentHash)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenContentHashes[tokenId] = contentHash;
    }

    function _setTokenMetadataHash(uint256 tokenId, bytes32 metadataHash)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenMetadataHashes[tokenId] = metadataHash;
    }

    function _setTokenMetadataURI(uint256 tokenId, string memory metadataURI)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenMetadataURIs[tokenId] = metadataURI;
    }

    function _setTapRate(uint256 tokenId, uint256 _tapRate)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenTapRates[tokenId] = _tapRate;
    }

    function _setLastWithdrawnTime(uint256 tokenId, uint256 _lastWithdrawnTime)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenLastWithdrawnTimes[tokenId] = _lastWithdrawnTime;
    }

    function _setTappableBalance(uint256 tokenId, uint256 _tappableBalance)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenTappableBalances[tokenId] = _tappableBalance;
    }

    function _setVotingPower(uint256 tokenId, uint256 _votingPower)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenVotingPowers[tokenId] = _votingPower;
    }

    /**
     * @notice Destroys `tokenId`.
     * @dev We modify the OZ _burn implementation to
     * maintain metadata and to remove the
     * previous token owner from the piece
     */
    function _burn(uint256 tokenId) internal override {
        string memory tokenURI = _tokenURIs[tokenId];

        super._burn(tokenId);

        if (bytes(tokenURI).length != 0) {
            _tokenURIs[tokenId] = tokenURI;
        }

        delete previousTokenOwners[tokenId];
    }

    /**
     * @notice transfer a token and remove the ask for it.
     * @param from address of NFT sender
     * @param to address of NFT receiver
     * @param tokenId to be sent
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
