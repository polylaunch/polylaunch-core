pragma solidity 0.7.4;

interface BasicLaunchInterface {
    function increase_tap(uint256 newRate) external;

    function initiateRefund() external;

    function totalVotingPower() external view returns (uint256);

    function launcher() external view returns (address);

    function launcherTapRate() external view returns (uint256);

    function increaseTap(uint256 newRate) external;

    function initiateRefundMode() external;

    function redeemExcess() external;
}