pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

interface IPolyVaultRegistry {

    struct Vault {
        uint256 vaultId;
        address vaultContractAddress;
        string vaultDesignation;
        uint256 vaultProvider;
        bool vaultActive;
    }

    function getRegisteredVault(uint256 _vaultId) external view returns (Vault memory);
}