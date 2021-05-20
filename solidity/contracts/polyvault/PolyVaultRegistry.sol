// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./PolyVault.sol";
import "../../interfaces/IPolyVaultRegistry.sol";
import "../system/PolylaunchSystemAuthority.sol";

/**
 * @title Registry of supported Vaults
 * @notice Storage for all supported pools/vaults on Polylaunch
 * @author Polylaunch Protocol
 */

contract PolyVaultRegistry is PolylaunchSystemAuthority, IPolyVaultRegistry {
    using Counters for Counters.Counter;

    ///
    /// Struct reference
    ///

    //    struct Vault {
    //        uint256 vaultId;
    //        address vaultContractAddress;
    //        string vaultDesignation;
    //        uint256 vaultProvider;
    //        bool vaultActive;
    //    }

    // storage for mapping vaultId to vault structs
    mapping(uint256 => IPolyVaultRegistry.Vault) public registeredVaults;

    // latest vaultId number
    Counters.Counter public vaultIdTracker;

    event NewVaultRegistered(
        uint256 indexed vaultId,
        address vaultContractAddress,
        string vaultDesignation
    );
    event VaultRemoved(
        uint256 indexed vaultId,
        address vaultContractAddress,
        string vaultDesignation
    );

    constructor(address polylaunchSystemAddress)
        PolylaunchSystemAuthority(polylaunchSystemAddress)
    {} // This calls the constructor of the PolylaunchSystemAuthority

    /*
     * @notice Register a new vault for use with PolyVault
     * @param _vaultContractAddress contract address for the specific interest bearing vault/pool
     * @param _vaultDesignation string definition of the vault/pool (for UX)
     * @param _vaultProvider the id of protocol that is providing the interest bearing vault/pool
     * @dev only the System can call this function
     */
    function registerNewVault(
        address _vaultContractAddress,
        string calldata _vaultDesignation,
        uint256 _vaultProvider
    ) external onlySystem {
        vaultIdTracker.increment();
        uint256 _vaultId = vaultIdTracker.current();
        IPolyVaultRegistry.Vault memory _vault =
            IPolyVaultRegistry.Vault({
                vaultId: _vaultId,
                vaultContractAddress: _vaultContractAddress,
                vaultDesignation: _vaultDesignation,
                vaultProvider: _vaultProvider,
                vaultActive: true
            });

        registeredVaults[_vaultId] = _vault;
        emit NewVaultRegistered(
            _vaultId,
            _vaultContractAddress,
            _vaultDesignation
        );
    }

    /*
     * @notice Get a registered vault by the id (will return deactivated vaults)
     * @param _vaultId the unique identifier for the vault to be viewed
     * @return the vault struct for the provided vault Id
     */
    function getRegisteredVault(uint256 _vaultId)
        external
        view
        override
        returns (IPolyVaultRegistry.Vault memory)
    {
        return registeredVaults[_vaultId];
    }

    /*
     * @notice Remove a registered vault
     * @param _vaultId the unique identifier for the vault to be removed
     * @dev only the System can call this function, sets the vaultActive function to false
     */
    function removeVault(uint256 _vaultId) external onlySystem {
        require(
            _vaultId <= vaultIdTracker.current(),
            "VaultRegistry: No Vault has been registered at this id"
        );
        registeredVaults[_vaultId].vaultActive = false;
        emit VaultRemoved(
            _vaultId,
            registeredVaults[_vaultId].vaultContractAddress,
            registeredVaults[_vaultId].vaultDesignation
        );
    }
}
