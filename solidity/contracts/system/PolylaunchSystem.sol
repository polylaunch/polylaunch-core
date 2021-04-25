// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../launch/LaunchFactory.sol";
import "../launch/BasicLaunch.sol";
import "../polyvault/PolyVaultRegistry.sol";
import "../venture-bond/VentureBond.sol";
import "../venture-bond/Market.sol";
import "../governance/LaunchGovernor.sol";
import "../../interfaces/BasicLaunchInterface.sol";
import "../../interfaces/IMarket.sol";
import {Decimal} from "../Decimal.sol";

import {LaunchLogger} from "../launch/LaunchLogger.sol";

/**
 * @title PolylaunchSystem the deployer of all base contracts
 * @notice In here we can have global governance functions if desired,
 * for example pausing all launches if a bug is found in the contracts.
 * This contract is also responsible for initialising the system. When deployed,
 * it creates the base auction contracts, passing them into the LaunchFactory constructor.
 * It also has the ability to update LaunchFactory dependencies, for example,
 * to change the contract addresses it uses to clone.
 * Any functions in here which update state should probably be onlyOwner.
 * owned by the creator, market to be modified.
 */

contract PolylaunchSystem is Ownable, LaunchLogger {
    using SafeERC20 for IERC20;
    
    event PolylaunchSystemLaunched(
        address factoryAddress,
        address systemAddress,
        address baseBasicLaunchAddress,
        address baseGovernorAddress,
        address marketAddress,
        address ventureBondAddress,
        address vaultRegistry
    );

    constructor(
        IERC20 usd,
        address basicLaunch,
        address governor
    ) {
        LaunchFactory launchFactory = new LaunchFactory(address(this));
        PolyVaultRegistry vaultRegistry = new PolyVaultRegistry(address(this));

        Market market = new Market(IMarket.BidShares(Decimal.D256(0e18), Decimal.D256(10e18), Decimal.D256(90e18)));
        VentureBond ventureBond = new VentureBond(address(market), address(this), address(launchFactory));
        market.configure(address(ventureBond));

        launchFactory.setBaseBasicLaunchAddress(basicLaunch);
        launchFactory.setMarketAddress(address(market));
        launchFactory.setVentureBondAddress(address(ventureBond));
        launchFactory.setBaseGovernorAddress(governor);
        launchFactory.setVaultRegistryAddress(address(vaultRegistry));
        launchFactory.setUsdContract(usd);

        emit PolylaunchSystemLaunched(
            address(launchFactory),
            address(this),
            basicLaunch,
            governor,
            address(market),
            address(ventureBond),
            address(vaultRegistry)
        );
    }

    /*
     * @notice Register a new vault for use with PolyVault
     * @param _vaultRegistryAddress the address of the vaultRegistry
     * @param _vaultContractAddress contract address for the specific interest bearing vault/pool
     * @param _vaultDesignation string definition of the vault/pool (for UX)
     * @param _vaultProvider the id of protocol that is providing the interest bearing vault/pool
     * @dev only the Owner can call this function
     */
    function registerNewVault(
        address _vaultRegistryAddress,
        address _vaultContractAddress,
        string calldata _vaultDesignation,
        uint256 _vaultProvider
    ) external onlyOwner {
        PolyVaultRegistry(_vaultRegistryAddress).registerNewVault(
            _vaultContractAddress,
            _vaultDesignation,
            _vaultProvider
        );
    }

    /*
     * @notice Remove a registered vault
     * @param _vaultRegistryAddress the address of the vaultRegistry
     * @param _vaultId the unique identifier for the vault to be removed
     * @dev only the Owner can call this function, sets the vaultActive function to false
     */
    function removeVault(
        address _vaultRegistryAddress,
        uint256 _vaultId
    ) external onlyOwner {
        PolyVaultRegistry(_vaultRegistryAddress).removeVault(
            _vaultId
        );
    }

    /*
     * @notice Collect balance from this contract
     * @param _tokens Tokens to collect
     * @param _payee Recipients of the collected balance
     * @dev only the Owner can call this function
     */
     function withdraw(IERC20[] calldata _tokens, address payable _payee) external onlyOwner {
         for (uint256 i=0; i < _tokens.length; i++) {
             IERC20 token = _tokens[i];
             uint256 tokenBalance = token.balanceOf(address(this));
             if (tokenBalance > 0) {
                 token.safeTransfer(_payee, tokenBalance);
             }
         }
         if (address(this).balance > 0) {
             _payee.transfer(address(this).balance);
         }
     }



}
