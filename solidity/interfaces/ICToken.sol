pragma solidity 0.7.4;

/**
 * @title Interface for Compound ERC20
 */
interface ICToken {

    function balanceOfUnderlying(address) external view returns (uint256);

}