pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPolyVault {
    function _deposit(address, uint256, uint256, IERC20, address) external;

    function _exitFromVault(address, IERC20, address) external;

    function _launcherYieldTap(address, uint256, IERC20, address, address) external;

}