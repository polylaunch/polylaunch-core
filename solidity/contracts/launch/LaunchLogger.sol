pragma solidity 0.7.4;

contract LaunchLogger {
    /*
    Logging philosophy:
      Every state transition should fire a log
      That log should have ALL necessary info for off-chain actors
      Everyone should be able to ENTIRELY rely on log messages
    */

    // ===== LaunchRedemption =====

    event LauncherFundsTapped(
        address indexed launchAddress,
        address indexed tapper,
        address recipient,
        uint256 amount
    );

    function logLauncherFundsTapped(
        address launchAddress,
        address tapper,
        address recipient,
        uint256 amount
    ) external {
        emit LauncherFundsTapped(launchAddress, tapper, recipient, amount);
    }

    event SupporterFundsTapped(
        address indexed launchAddress,
        address indexed tapper,
        uint256 tokenId,
        uint256 amount,
        uint256 newTappableBalance
    );

    function logSupporterFundsTapped(
        address launchAddress,
        address tapper,
        uint256 tokenId,
        uint256 amount,
        uint256 newTappableBalance
    ) external {
        emit SupporterFundsTapped(
            launchAddress,
            tapper,
            tokenId,
            amount,
            newTappableBalance
        );
    }

    event TokensWithdrawnAfterFailedLaunch(address indexed launchAddress);

    function logTokensWithdrawnAfterFailedLaunch(address launchAddress)
        external
    {
        emit TokensWithdrawnAfterFailedLaunch(launchAddress);
    }

    event UnsoldTokensWithdrawn(address indexed launchAddress, uint256 amount);

    function logUnsoldTokensWithdrawn(address launchAddress, uint256 amount)
        external
    {
        emit UnsoldTokensWithdrawn(launchAddress, amount);
    }

    // ===== LaunchGovernance =====

    event RefundClaimed(
        address indexed launchAddress,
        address addr,
        uint256 amount,
        uint256 tokenId
    );

    function logRefundClaimed(
        address launchAddress,
        address addr,
        uint256 amount,
        uint256 tokenId
    ) external {
        emit RefundClaimed(launchAddress, addr, amount, tokenId);
    }

    event TapIncreased(
        address indexed launchAddress,
        uint256 oldRate,
        uint256 newRate
    );

    function logTapIncreased(
        address launchAddress,
        uint256 oldRate,
        uint256 newRate
    ) external {
        emit TapIncreased(launchAddress, oldRate, newRate);
    }

    event RefundModeInitiated(address indexed launchAddress);

    function logRefundModeInitiated(address launchAddress) external {
        emit RefundModeInitiated(launchAddress);
    }

    event FundsWithdrawn(
        address indexed launchAddress,
        address indexed account,
        uint256 amount
    );

    function logFundsWithdrawn(
        address launchAddress,
        address account,
        uint256 amount
    ) external {
        emit FundsWithdrawn(launchAddress, account, amount);
    }

    // ===== LaunchVault =====

    event VaultFundsDeposited(
        address indexed launchAddress,
        uint256 amount,
        uint256 vaultProvider,
        uint256 vaultId
    );

    function logVaultFundsDeposited(
        address launchAddress,
        uint256 amount,
        uint256 vaultProvider,
        uint256 vaultId
    ) external {
        emit VaultFundsDeposited(launchAddress, amount, vaultProvider, vaultId);
    }

    event VaultFundsTapped(
        address indexed launchAddress,
        uint256 indexed amount
    );

    function logVaultFundsTapped(address launchAddress, uint256 amount)
        external
    {
        emit VaultFundsTapped(launchAddress, amount);
    }

    event VaultExited(address indexed launchAddress);

    function logVaultExited(address launchAddress) external {
        emit VaultExited(launchAddress);
    }

    // ===== LaunchFactory =====

    event BasicLaunchCreated(
        address indexed basicLaunchAddress,
        address ventureBondAddress,
        address marketAddress,
        address governorAddress,
        uint256 launchId,
        string ipfsHash
    );

    function logBasicLaunchCreated(
        address _basicLaunchAddr,
        address _ventureBondAddr,
        address _marketAddr,
        address _governorAddr,
        uint256 _launchId,
        string calldata _ipfsHash
    ) external {
        emit BasicLaunchCreated(
            _basicLaunchAddr,
            _ventureBondAddr,
            _marketAddr,
            _governorAddr,
            _launchId,
            _ipfsHash
        );
    }

    // ===== BasicLaunch =====

    event SupporterFundsDeposited(
        address indexed launchAddress,
        address sender,
        uint256 amount
    );

    function logSupporterFundsDeposited(
        address launchAddress,
        address sender,
        uint256 amount
    ) external {
        emit SupporterFundsDeposited(launchAddress, sender, amount);
    }
}
