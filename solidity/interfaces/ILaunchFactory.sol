pragma solidity 0.7.4;

import "../../interfaces/IVentureBond.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Interface for Compound ERC20
 */
interface ILaunchFactory {
    /**
     * @notice struct to store information required for deploying a basic launch
     */
    struct LaunchInfo {
        // recipients of any invested funds (token owner)
        address _fundRecipient;
        // contract of token to be sold
        IERC20 _token;
        // amount of tokens for sale
        uint256 _totalForSale;
        // start date of the launch
        uint256 _startDate;
        // end date of the launch
        uint256 _endDate;
        // minimum funding required for the launch to succeed
        uint256 _minimumFunding;
        // launcher initial vested period (in seconds)
        uint256 _initialLauncherVesting;
        // supporter initial vested period (in seconds)
        uint256 _initialSupporterVesting;
        // the total amount of funds a launch can receive (DAI)
        uint256 _fundingCap;
        // the max amount an individual address is allowed to contribute (DAI)
        uint256 _individualFundingCap;
        // the fixed swap rate of the sale DAI/TOKEN (e.g. for 100 tokens for one dai, the value should be 100e18)
        uint256 _fixedSwapRate;
        // generic data for an NFT
        IVentureBond.MediaData _genericNftData;
        // IPFS hash where launch details such as name, logo and description are stored
        string _ipfsHash;
    }

    function getVaultRegistryAddress() external returns (address);
}
