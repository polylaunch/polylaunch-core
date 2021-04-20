pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../../interfaces/IVentureBond.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

library VentureBondDataRegistry {
    using Counters for Counters.Counter;
    struct Register {
        // mapping to store the nft Data by index
        mapping(uint256 => IVentureBond.MediaData) nftData;
        // mapping to track whether a token has been minted or not
        mapping(uint256 => bool) isIndexMinted;
        // mapping to track order of investment
        mapping(address => uint256) supporterIndex;
        // counter to track latest supporterIndex
        Counters.Counter supporterTracker;
    }

    /**
     * @notice Ensure that the provided nft data is valid
     */
    modifier onlyValidNftData(IVentureBond.MediaData memory _nftData) {
        require(
            _nftData.metadataHash != 0,
            "VentureBondDataRegistry: metadata hash must be non-zero"
        );
        require(
            bytes(_nftData.tokenURI).length != 0,
            "VentureBondDataRegistry: token URI must be non-empty"
        );
        _;
    }

    event NftDataAdded(
        uint256 indexed i,
        IVentureBond.MediaData _nftData
    );

    /**
     * @notice get the nft URIs and hashes of a token by ID
     * @param self Data struct associated with the launch
     * @param i index of the token which data is to be checked
     * @return a MediaData struct containing the stored NFT URIs and hashes for that given token
     */
    function getNftDataByIndex(Register storage self, uint256 i)
        public
        returns (IVentureBond.MediaData memory)
    {
        return self.nftData[i];
    }

    /**
     * @notice set the NFT URIs and hashes of a tokenId
     * @param self Data struct associated with the launch
     * @param i index of the token to assign the nft data
     * @param _nftData MediaData struct containing the data for the tokenId
     */
    function setNftDataByIndex(
        Register storage self,
        uint256 i,
        IVentureBond.MediaData memory _nftData
    ) internal onlyValidNftData(_nftData) {
        require(
            !self.isIndexMinted[i],
            "VentureBondDataRegistry: This token has already been minted, its data cannot be changed"
        );
        self.nftData[i] = _nftData;

        emit NftDataAdded(i, _nftData);
    }

    /**
     * @notice set the NFT URIs and hashes of multiple tokenIds at once
     * @param self Data struct associated with the launch
     * @param i_s list of indexes of tokens to be set, the indexes of the tokenId and its data in _nftData
     * must correspond
     * @param _nftData array of MediaData structs storing the nft data for the tokenId in the corresponding
     * index of tokenIds
     */
    function batchSetNftDataByIndex(
        Register storage self,
        uint256[] memory i_s,
        IVentureBond.MediaData[] memory _nftData
    ) internal {
        require(
            i_s.length == _nftData.length,
            "VentureBondDataRegistry: Arrays must be the same length"
        );
        for (uint256 i = 0; i < i_s.length; i++) {
            setNftDataByIndex(self, i_s[i], _nftData[i]);
        }
    }
}