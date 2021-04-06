// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

/// @title  Polylaunch System Authority.
/// @notice Contract to secure function calls to that only the System contract should be able to use.
/// @dev    The `PolylaunchSystem` contract address is passed as a constructor parameter.
contract PolylaunchSystemAuthority {
    address public polylaunchSystemAddress;

    /// @notice Set the address of the System contract on contract initialization.
    constructor(address _polylaunchSystemAddress) {
        polylaunchSystemAddress = _polylaunchSystemAddress;
    }

    /// @notice Function modifier ensures modified function is only called by Polylaunch system
    modifier onlySystem() {
        require(
            msg.sender == polylaunchSystemAddress,
            "Caller must be PolylaunchSystem contract"
        );
        _;
    }
}
