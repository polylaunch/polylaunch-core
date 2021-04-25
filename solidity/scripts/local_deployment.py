import time
from brownie import (
    LaunchRedemption,
    LaunchLogger,
    LaunchGovernance,
    LaunchVault,
    LaunchFactory,
    BasicLaunch,
    BasicERC20,
    GovernableERC20,
    LaunchUtils,
    PolylaunchConstants,
    PolylaunchSystem,
    PolylaunchSystemAuthority,
    VentureBondDataRegistry,
    PolyVaultRegistry,
    GovernorAlpha,
    VentureBond,
    Market,
    accounts,
    web3,
    Wei,
    chain,
    Contract,
)

AMOUNT_FOR_SALE = 9_000_000e18
AAVE_LENDING_POOL = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
LOCAL_METAMASK_WALLETS = [
    "0xb0151Bc462c1a19d86383a56Aef9ae3dEFd99a4B",
    "0xe2Ea8169785B9598198b94a7ba3dbD6f7Ef28DE3",
]


def get_external_dependencies():
    return (
        Contract.from_explorer("0x6B175474E89094C44Da98b954EedeAC495271d0F"),
        Contract.from_explorer("0x5d3a536e4d6dbd6114cc1ead35777bab948e3643"),
        Contract.from_explorer("0x19D3364A399d251E894aC732651be8B0E4e85001"),
        Contract.from_explorer("0x028171bCA77440897B824Ca71D1c56caC55b68A3"),
    )


def fake_dai():
    contract = BasicERC20.deploy("Dai Stablecoin", "DAI", {"from": accounts[0]})
    for account in accounts:
        usd_contract.mint(10000e18, {"from": account})


def main():
    deployer = accounts[0]

    # get external dependencies
    dai, cdai, ydai, adai = get_external_dependencies()

    # send dai to all accounts
    dai_whale = accounts.at("0x3f5ce5fbfe3e9af3971dd833d26ba9b5c936f0be", force=True)
    for account in accounts:
        dai.transfer(account, 10000e18, {"from": dai_whale})

    # send 100 eth and 10k dai to local metamask accounts
    for account in LOCAL_METAMASK_WALLETS:
        dai.transfer(account, 10000e18, {"from": dai_whale})
        dai_whale.transfer(account, 100e18)

    # deploy an ERC20 token to test launches with
    GovernableERC20.deploy(
        accounts[1],
        accounts[1],
        chain.time() + 1000,
        "DummyToken",
        "TKN",
        AMOUNT_FOR_SALE,
        {"from": accounts[1]},
    )

    # deploy constants
    PolylaunchConstants.deploy({"from": deployer})
    # deploy NFT data registry
    VentureBondDataRegistry.deploy({"from": deployer})
    # deploy utils library
    LaunchUtils.deploy({"from": deployer})
    # deploy redemption library
    LaunchRedemption.deploy({"from": deployer})
    # deploy log library
    LaunchLogger.deploy({"from": deployer})
    # deploy governance library
    LaunchGovernance.deploy({"from": deployer})
    # deploy base governor
    governor = GovernorAlpha.deploy({"from": deployer})
    # deploy base launch contract
    launch = BasicLaunch.deploy({"from": deployer})
    # deploy system contract
    system = PolylaunchSystem.deploy(
        dai.address,
        launch.address,
        governor.address,
        {"from": deployer},
    )
    # deploy system authority
    auth = PolylaunchSystemAuthority.deploy(system.address, {"from": deployer})
    # deploy launch factory
    factory = LaunchFactory.at(
        system.tx.events["PolylaunchSystemLaunched"]["factoryAddress"]
    )
    # deploy vault registry
    vault_registry = PolyVaultRegistry.at(
        system.tx.events["PolylaunchSystemLaunched"]["vaultRegistry"]
    )
    # register vaults
    system.registerNewVault(
        vault_registry.address, cdai.address, "COMPOUND_DAI", 1, {"from": deployer}
    )
    system.registerNewVault(
        vault_registry.address, ydai.address, "YEARN_VAULTS_DAI", 2, {"from": deployer}
    )
    system.registerNewVault(
        vault_registry.address,
        AAVE_LENDING_POOL,
        "AAVE_LENDING_DAI",
        3,
        {"from": deployer},
    )
