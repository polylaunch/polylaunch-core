// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./LaunchUtils.sol";
import "../venture-nft/VentureBondDataRegistry.sol";
import "../venture-nft/Market.sol";
import "../../interfaces/IVentureBond.sol";
import "../../interfaces/IMarket.sol";
import "../../interfaces/ILaunchFactory.sol";
import "../polyvault/PolyVault.sol";
import {LaunchRedemption} from "./LaunchRedemption.sol";
import {LaunchGovernance} from "./LaunchGovernance.sol";
import {LaunchVault} from "./LaunchVault.sol";

/**
 * @author PolyLaunch Protocol
 * @title Basic launch
 * @notice A PolyLaunch DAICO launch contract following a fixed price mechanism
 */
contract BasicLaunch is PolyVault, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using LaunchUtils for LaunchUtils.Data;
    using LaunchRedemption for LaunchUtils.Data;
    using LaunchGovernance for LaunchUtils.Data;
    using LaunchVault for LaunchUtils.Data;

    using VentureBondDataRegistry for VentureBondDataRegistry.Register;

    // storage struct for all information pertaining to a particular Launch
    LaunchUtils.Data self;

    VentureBondDataRegistry.Register register;

    // variable to ensure that the setOwnership is only called once
    bool private ownershipSet;

    /**
     * @notice modifier to check that the configured token launcher is making the call
     */
    modifier onlyLauncher() {
        require(msg.sender == self.launcher, "Caller must be launcher");
        _;
    }

    /**
     * @notice modifier to check that configured factory is making a call
     */
    modifier onlyFactory() {
        require(
            msg.sender == self.launchFactory,
            "Caller must be launchFactory"
        );
        _;
    }

    /**
     * @notice modifier to check that configured governor is making a call
     */
    modifier onlyGovernor() {
        require(
            msg.sender == self.governor,
            "Caller must be governor"
        );
        _;
    }

    event FundsDeposited(address indexed supporter, uint256 amount);

    /**
     * @notice set the ownership of the contract, sets the owner of the contract which is the token launcher
     * and the factory address, these are used for modifiers onlyLauncher() and onlyFactory()
     * @param _factory factory that is allowed to call onlyFactory() functions
     * @param _launcher token launcher that is allowed to call onlyLauncher() functions
     * @dev can only be called once
     */
    function setOwnership(
        address _factory,
        address _launcher,
        address _governor
    ) public {
        require(!ownershipSet, "Already initiated");
        require(_factory != address(0), "Factory cannot be zero address.");
        require(_launcher != address(0), "Launcher cannot be zero address.");
        require(
            _governor != address(0),
            "Governor cannot be zero address."
        );

        self.launchFactory = _factory;
        self.launcher = _launcher;
        self.governor = _governor;
        ownershipSet = true;
    }

    /**
     * @notice function to initiate the basic launch and provide its data for activation, can only be called by the factory.
     * params defined in launchInfo struct in LaunchFactory.sol
     * @dev can only be called once
     */
    function init(
        IERC20 _usd,
        ILaunchFactory.LaunchInfo memory launchInfo,
        address _ventureBondContract,
        address _marketContract,
        address _system,
        uint256 _launchId
    ) public onlyFactory {
        require(!self.initialised, "Contract already initialised");
        require(
            launchInfo._startDate > block.timestamp,
            "Start date cannot be in the past"
        );
        require(
            launchInfo._endDate > launchInfo._startDate,
            "End date cannot be before start date"
        );
        require(
            launchInfo._minimumFunding > 0,
            "The minimum funding amount must be greater than 0"
        );
        require(
            (launchInfo._fundingCap.mul(launchInfo._fixedSwapRate)).div(1e18) 
            <= launchInfo._totalForSale, "Insufficient tokens provided for the given swap rate"
        );

        self.launchId = _launchId;
        self.polylaunchSystem = _system;
        self.USD = _usd;
        self.TOKEN = launchInfo._token;
        self.TOTAL_TOKENS_FOR_SALE = launchInfo._totalForSale;
        self.START = launchInfo._startDate;
        self.END = launchInfo._endDate;
        self.MINIMUM_FUNDING = launchInfo._minimumFunding;
        self.FUNDING_CAP = launchInfo._fundingCap;
        self.INDIVIDUAL_FUNDING_CAP = launchInfo._individualFundingCap == 0 ? 2^256-1 : launchInfo._individualFundingCap;
        self.FIXED_SWAP_RATE = launchInfo._fixedSwapRate;
        self.fundRecipient = launchInfo._fundRecipient;
        self.launcherTapRate = launchInfo._initialLauncherTapRate;
        self.supporterTapRate = launchInfo._initialSupporterTapRate;
        self.lastWithdrawn = launchInfo._endDate;
        self.ventureBondAddress = _ventureBondContract;
        self.marketAddress = _marketContract;
        self.genericNftData = launchInfo._genericNftData;
        self.TOKEN.safeTransferFrom(
            msg.sender,
            address(this),
            launchInfo._totalForSale
        );
        self.initialised = true;
    }

    receive() external payable {
        revert();
    }

    /**
     * @notice Allows an address to send in DAI to invest in the DAICO
     * @param amount the amount the address would like to invest
     */
    function sendUSD(uint256 amount) external{
        require(
            block.timestamp >= self.START,
            "Launch not started"
        );
        require(block.timestamp < self.END, "Launch has ended");
        require(
            self.totalFunding.add(amount) <= self.FUNDING_CAP,
            "Launch has reached funding cap"
        );
        require(
            self.provided[msg.sender].add(amount) <= self.INDIVIDUAL_FUNDING_CAP,
            "You have reached the individual funding cap"
        );
        require(
            self.USD.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        self.totalFunding += amount;
        self.provided[msg.sender] += amount;

        emit FundsDeposited(msg.sender, amount);
    }

    /**
     * @notice Claim function for an supporter to either claim and mint their NFT for a successful launch or
     * retrieve their DAI after a failed launch
     */
    function claim() external nonReentrant {
        self.claim(register);
    }

    /**
     * @notice Launcher withdraws all tokens they provided if the minimum funding amount is not reached.
     */
    function withdrawTokenAfterFailedLaunch() external onlyLauncher{
        self.withdrawTokenAfterFailedLaunch();
    }

    /**
     * @notice Launcher withdraws all tokens that were not sold during the sale window.
     */
    function withdrawUnsoldTokens() external onlyLauncher{
        self.withdrawUnsoldTokens();
    }

    /**
     * @notice Launcher tap for receiving DAI that they are entitled to.
     */
    function launcherTap() external onlyLauncher {
        self.launcherTap();
    }

    /**
     * @notice Supporter tap for receiving tokens that they are entitled to.
     * @param tokenId the id of the token that the supporter owns
     */
    function supporterTap(uint256 tokenId) external nonReentrant {
        self.supporterTap(tokenId);
    }

    /**
     * @notice activate deposit into the PolyVault
     * @param vaultId the unique identifier of the vault the launcher wants to deploy funds to, refer to VaultRegistry
     */
    function deposit(uint256 vaultId) external onlyLauncher{
        self.deposit(vaultId);
    }

    /**
     * @notice exit from a PolyVault
     */
    function exitFromVault() external onlyLauncher{
        self.exitFromVault();
    }

    /**
     * @notice View function to check the funds provided to the launch
     * @return the total amount of DAI provided to the launch
     */
    function totalFundsProvided() external view returns (uint256) {
        return self.totalFundsProvided();
    }

    /**
     * @notice View function to check a user's funds provided to the launch
     * @param addr participant address to be checked
     * @return the funds provided by the provided address
     */
    function fundsProvidedByAddress(address addr)
        external
        view
        returns (uint256)
    {
        return self.fundsProvidedByAddress(addr);
    }

    /**
     * @notice View function to check the start time of the launch
     * @return the start time of the launch
     */
    function launchStartTime() external view returns (uint256) {
        return self.launchStartTime();
    }

    /**
     * @notice View function to check the end time of the launch
     * @return the end time of the launch
     */
    function launchEndTime() external view returns (uint256) {
        return self.launchEndTime();
    }

    /**
     * @notice View function to return the contract of the token being sold
     * @return IERC20 interface of the token being sold
     */
    function tokenForLaunch() external view returns (IERC20) {
        return self.tokenForLaunch();
    }

    /**
     * @notice View function to return the launcher of the contract
     * @return address of the launcher
     */
    function launcher() public view returns (address) {
        return self.launcher;
    }

    /**
     * @notice View function to return the address of the governer contract
     * @return address of the governer contract
     */
    function governor() public view returns (address) {
        return self.governor;
    }

    /**
     * @notice View function to return the launchId
     * @return the launchId
     */
    function launchId() external view returns (uint256) {
        return self.launchId;
    }

    /**
     * @notice View function to return the tap rate for the launchers (wei/sec)
     * @return uint256 of the tap rate
     */
    function launcherTapRate() public view returns (uint256) {
        return self.launcherTapRate;
    }

    /**
     * @notice View function to return the address of the VentureBond contract associated with the launch
     * @return VentureBond contract associated with the launch
     */
    function launchVentureBondAddress() external view returns (address) {
        return self.launchVentureBondAddress();
    }

    /**
     * @notice View function to return the address of the Market contract associated with the launch
     * @return Market contract associated with the launch
     */
    function launchMarketAddress() external view returns (address) {
        return self.launchMarketAddress();
    }

    /**
     * @notice Governance function. Increases the launcher tap rate.
     */
    function increaseTap(uint256 newRate) public onlyGovernor {
        self.increaseTap(newRate);
    }

    /**
     * @notice Returns total voting power available in launch
     */
    function totalVotingPower() public view returns (uint256) {
        return self.totalVotingPower;
    }

    /**
     * @notice Getter for data registry basic nft data by tokenId
     * @param tokenId id of the token to check
     */
    function getNftDataByTokenId(uint256 tokenId)
        external
        returns (IVentureBond.BaseNFTData memory)
    {
        return register.getNftDataByTokenId(tokenId);
    }

    /**
     * @notice Setter for data registry basic nft data by tokenId
     * @param tokenId id of the token to associate with given nftData
     * @param _nftData BaseNFTData struct that will be used when minting the nft with the associated tokenId
     */
    function setNftDataByTokenId(
        uint256 tokenId,
        IVentureBond.BaseNFTData memory _nftData
    ) external onlyLauncher {
        register.setNftDataByTokenId(tokenId, _nftData);
    }

    /**
     * @notice Batch setter for data registry basic nft data by tokenId
     * @param tokenIds list of token ids to be associated with corresponding baseNftData structs in _nftData array
     * @param _nftData list holding BaseNFTData structs to be assigned to the corresponding tokenId
     */
    function batchSetNftDataByTokenId(
        uint256[] memory tokenIds,
        IVentureBond.BaseNFTData[] memory _nftData
    ) external onlyLauncher {
        register.batchSetNftDataByTokenId(tokenIds, _nftData);
    }

    /**
     * @notice Puts the launch into refund mode, which allows contributors to claim back their USD proportional to their token balance
     */
    function initiateRefundMode() public onlyGovernor {
        self.initiateRefundMode();
    }

    /**
     * @notice Allows venture bond owners to claim a USD refund if the launch is in refund mode.
     * @param tokenId id of the venture bond to claim the refund against
     */
    function claimRefund(uint256 tokenId) public returns (uint256) {
        return self.claimRefund(tokenId);
    }
}
