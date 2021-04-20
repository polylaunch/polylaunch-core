// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./BasicLaunch.sol";
import "../proxy/CloneFactory.sol";
import "../venture-bond/VentureBond.sol";
import "../venture-bond/Market.sol";
import "../system/PolylaunchSystemAuthority.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import "../governance/LaunchGovernor.sol";
import "../../interfaces/IVentureBond.sol";
import "../../interfaces/ILaunchFactory.sol";
import {LaunchLogger} from "./LaunchLogger.sol";

/**
 * @author PolyLaunch Protocol
 * @title launch factory
 * @notice The factory that can deploy DAICOs
 */
contract LaunchFactory is CloneFactory, PolylaunchSystemAuthority, ILaunchFactory {
    using Counters for Counters.Counter;
    // address of the launch contract used as template for proxies
    address public baseBasicLaunchAddress;
    // address of the Venture Bond contract
    address public ventureBondAddress;
    // address of the Market contract
    address public marketAddress;
    // address of the Governor contract
    address public baseGovernorAddress;
    // address of the Vault registry contract
    address private vaultRegistryAddress;
    // IERC20 interface for DAI
    IERC20 public usdAddress;
    // tracker for the number of launches
    Counters.Counter public launchIdTracker;
    //   address public baseDutchAuctionAddress; future (example)
    //   address public nftTokenAddress; future (example)

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
            "VentureBondDataRegistry: token URI must be non-zero"
        );
        _;
    }

    constructor(address polylaunchSystemAddress)
        PolylaunchSystemAuthority(polylaunchSystemAddress)
    {} // This calls the constructor of the PolylaunchSystemAuthority

    /**
     * @notice sets the template address for the BasicLaunch contract
     * @param _baseBasicLaunchAddress the address of the BasicLaunch template contract
     */
    function setBaseBasicLaunchAddress(address _baseBasicLaunchAddress)
        public
        onlySystem
    {
        baseBasicLaunchAddress = _baseBasicLaunchAddress;
    }

    /**
     * @notice sets the template address for the VentureBond contract
     * @param _ventureBondAddress the address of the VentureBond template contract
     */
    function setVentureBondAddress(address _ventureBondAddress)
        public
        onlySystem
    {
        ventureBondAddress = _ventureBondAddress;
    }

    /**
     * @notice sets the template address for the market contract
     * @param _marketAddress the address of the market template contract
     */
    function setMarketAddress(address _marketAddress)
        public
        onlySystem
    {
        marketAddress = _marketAddress;
    }

    /**
     * @notice sets the template address for the governor contract
     * @param _baseGovernorAddress the address of the governor template contract
     */
    function setBaseGovernorAddress(address _baseGovernorAddress)
        public
        onlySystem
    {
        baseGovernorAddress = _baseGovernorAddress;
    }

    /**
     * @notice sets the DAI contract to be passed into launches
     * @param _usdAddress IERC20 contract to be used as the DAI address
     */
    function setUsdContract(IERC20 _usdAddress) public onlySystem {
        usdAddress = _usdAddress;
    }

    function setVaultRegistryAddress(address _vaultRegistryAddress)
        public
        onlySystem
    {
        vaultRegistryAddress = _vaultRegistryAddress;
    }

    function getVaultRegistryAddress() public override returns (address) {
        return vaultRegistryAddress;
    }

    /**
     * @notice return the launch id of the next launch (the current launchid)
     * @return the launchId of the next launch
     */
    function launchIdCounter() public view returns (uint256) {
        return launchIdTracker.current();
    }

    /**
     * @notice creates a basic launch and emits an event with the associated market and VentureBond addresses of the launch
     * @param launchInfo struct data for launchInfo data to configure the launch
     * @return created Basic launch address
     */
    function createBasicLaunch(ILaunchFactory.LaunchInfo memory launchInfo)
        external
        onlyValidNftData(launchInfo._genericNftData)
        returns (address)
    {
        address createdBasicLaunchAddr = createClone(baseBasicLaunchAddress);
        BasicLaunch clone = BasicLaunch(payable(createdBasicLaunchAddr));
        uint256 launchId_ = launchIdTracker.current();
        launchIdTracker.increment();
        address createdGovernorAddr = createClone(baseGovernorAddress);

        clone.setOwnership(address(this), msg.sender, createdGovernorAddr);

        GovernorAlpha governorClone =
            GovernorAlpha(payable(createdGovernorAddr));
        IVentureBond(ventureBondAddress).authoriseLaunch(createdBasicLaunchAddr);
        require(
            launchInfo._token.transferFrom(
                msg.sender,
                address(this),
                launchInfo._totalForSale
            ),
            "token transfer to factory failed"
        );
        require(
            launchInfo._token.approve(address(clone), launchInfo._totalForSale),
            "error sending tokens from factory to launch"
        );

        initiateBasicLaunch(
            clone,
            launchInfo,
            ventureBondAddress,
            marketAddress,
            launchId_
        );
        governorClone.init(
            "Governor",
            createdBasicLaunchAddr,
            address(launchInfo._token),
            ventureBondAddress
        );
        LaunchLogger(polylaunchSystemAddress).logBasicLaunchCreated(
                createdBasicLaunchAddr,
                marketAddress,
                ventureBondAddress,
                createdGovernorAddr,
                launchId_
        );
        return createdBasicLaunchAddr;
    }

    /**
     * @notice initiates the created BasicLaunch function of a BasicLaunch contract that has been created
     * @param basicLaunch the basic launch contract to be initiated
     * @param launchInfo struct data for the launchInfo to be provided in initiation
     * @param createdVentureBondAddr the Venture Bond address to be associated with this launch
     * @param createdMarketAddr the Market address to be associated with this launch
     */
    function initiateBasicLaunch(
        BasicLaunch basicLaunch,
        ILaunchFactory.LaunchInfo memory launchInfo,
        address createdVentureBondAddr,
        address createdMarketAddr,
        uint256 launchId
    ) internal {
        basicLaunch.init(
            usdAddress,
            launchInfo,
            createdVentureBondAddr,
            createdMarketAddr,
            polylaunchSystemAddress,
            launchId
        );
    }

    receive() external payable {
        revert();
    }
}
