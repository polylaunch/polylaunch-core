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
        // the tap rate for launcher (wei/sec)
        uint256 _initialLauncherTapRate;
        // the tap rate for supporters (wei/sec)
        uint256 _initialSupporterTapRate;
        // the total amount of funds a launch can receive (DAI)
        uint256 _fundingCap;
        // desired name of the NFT associated with the launch
        string _nftName;
        // desired symbol of the NFT associated with the launch
        string _nftSymbol;
        // generic data for an NFT
        IVentureBond.BaseNFTData _genericNftData;
    }

    function getVaultRegistryAddress() external returns (address);

}