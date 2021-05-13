pragma solidity 0.7.4;

/**
 * @title Interface for Aave
 */
interface ILendingPool {
    function deposit(address, uint256, address, uint16) external;
    function withdraw(address, uint256, address) external returns (uint256);
}

interface IStkAave {
    function claimRewards(address[] calldata ,address, uint256) external;
}