// SPDX-License-Identifier: MIT

pragma solidity 0.7.4;

interface IVault {
    function token() external view returns (address);
    function underlying() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function controller() external view returns (address);
    function governance() external view returns (address);
    function pricePerShare() external view returns (uint256);
    function deposit(uint256) external;
    function depositAll() external;
    function withdraw(uint256) external returns (uint256);
    function withdraw() external returns (uint256);
    function balanceOf(address) external returns (uint256);
}