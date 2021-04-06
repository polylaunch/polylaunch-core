pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../../interfaces/IVentureBond.sol";

library VentureBondDataRegistry {
    struct Register {
        // mapping to store the nft Data by tokenId
        mapping(uint256 => IVentureBond.BaseNFTData) nftData;
        // mapping to track whether a token has been minted or not
        mapping(uint256 => bool) isNftMinted;
    }

    /**
     * @notice Ensure that the provided nft data is valid
     */
    modifier onlyValidNftData(IVentureBond.BaseNFTData memory _nftData) {
        require(
            _nftData.contentHash != 0,
            "VentureBondDataRegistry: content hash must be non-zero"
        );
        require(
            _nftData.metadataHash != 0,
            "VentureBondDataRegistry: metadata hash must be non-zero"
        );
        require(
            bytes(_nftData.tokenURI).length != 0,
            "VentureBondDataRegistry: token URI must be non-empty"
        );
        require(
            bytes(_nftData.metadataURI).length != 0,
            "VentureBondDataRegistry: metadata URI must be non-empty"
        );
        _;
    }

    event NftDataAdded(
        uint256 indexed _tokenId,
        IVentureBond.BaseNFTData _nftData
    );

    /**
     * @notice get the nft URIs and hashes of a token by ID
     * @param self Data struct associated with the launch
     * @param tokenId id of the token which data is to be checked
     * @return a BaseNFTData struct containing the stored NFT URIs and hashes for that given token
     */
    function getNftDataByTokenId(Register storage self, uint256 tokenId)
        public
        returns (IVentureBond.BaseNFTData memory)
    {
        return self.nftData[tokenId];
    }

    /**
     * @notice set the NFT URIs and hashes of a tokenId
     * @param self Data struct associated with the launch
     * @param tokenId id of the token to assign the nft data
     * @param _nftData BaseNFTData struct containing the data for the tokenId
     */
    function setNftDataByTokenId(
        Register storage self,
        uint256 tokenId,
        IVentureBond.BaseNFTData memory _nftData
    ) internal onlyValidNftData(_nftData) {
        require(
            !self.isNftMinted[tokenId],
            "VentureBondDataRegistry: This token has already been minted, its data cannot be changed"
        );
        self.nftData[tokenId] = _nftData;

        emit NftDataAdded(tokenId, _nftData);
    }

    /**
     * @notice set the NFT URIs and hashes of multiple tokenIds at once
     * @param self Data struct associated with the launch
     * @param tokenIds list of token ids of tokens to be set, the indexes of the tokenId and its data in _nftData
     * must correspond
     * @param _nftData array of BaseNFTData structs storing the nft data for the tokenId in the corresponding
     * index of tokenIds
     */
    function batchSetNftDataByTokenId(
        Register storage self,
        uint256[] memory tokenIds,
        IVentureBond.BaseNFTData[] memory _nftData
    ) internal {
        require(
            tokenIds.length == _nftData.length,
            "VentureBondDataRegistry: Arrays must be the same length"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            setNftDataByTokenId(self, tokenIds[i], _nftData[i]);
        }
    }
}
