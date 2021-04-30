import time
import scripts.constants_mainnet as constants
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
import ipfshttpclient
import os
import json
from random import randint, random


AMOUNT_FOR_SALE = 9_000_000e18
AAVE_LENDING_POOL = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
LOCAL_METAMASK_WALLETS = [
    "0xb0151Bc462c1a19d86383a56Aef9ae3dEFd99a4B",
    "0xe2Ea8169785B9598198b94a7ba3dbD6f7Ef28DE3",
]


def mint_fake_dai_and_distribute(accts):
    contract = BasicERC20.deploy("Dai Stablecoin", "DAI", {"from": accounts[0]})
    for account in accts[:9]:
        contract.mint(1_000_000e18, {"from": account})

    # for account in LOCAL_METAMASK_WALLETS:
    #     contract.mint(1000e18, {"from": account})
    return contract


def main():
    client = ipfshttpclient.connect("/ip4/0.0.0.0/tcp/5001")

    script_dir = os.path.dirname(__file__)

    with open(os.path.join(script_dir, "launches.jsonl"), "r") as f:
        launches = eval(f.read())

    ipfs_hashes = []

    for launch in launches:
        res = client.add_str(json.dumps(launch, indent=4))
        ipfs_hashes.append(res)

    deployer = accounts[0]

    dai_contract = mint_fake_dai_and_distribute(accounts)

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
        dai_contract.address,
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

    for i, sale_details in enumerate(ipfs_hashes):
        current_sale_owner = i
        random_multiplier = randint(1, 5) + random()
        # start a sale
        token_for_sale = GovernableERC20.deploy(
            accounts[i],
            accounts[i],
            chain.time() + 200000,
            "DummyToken",
            "TKN",
            constants.AMOUNT_FOR_SALE * random_multiplier + 100e18,
            {"from": accounts[i]},
        )

        token_for_sale.approve(
            factory.address,
            constants.AMOUNT_FOR_SALE * random_multiplier + 100e18,
            {"from": accounts[i]},
        )
        now = chain.time()
        launch = factory.createBasicLaunch(
            [
                accounts[i],
                token_for_sale.address,
                constants.AMOUNT_FOR_SALE * random_multiplier,
                now + 50000,
                now + 86400000 * random(),
                constants.MINIMUM_FUNDING * random_multiplier,
                constants.INITIAL_DEV_VESTING,
                constants.INITIAL_INV_VESTING,
                constants.INDIVIDUAL_FUNDING_CAP * random_multiplier,
                constants.FIXED_SWAP_RATE,
                constants.GENERIC_NFT_DATA,
                sale_details,
            ],
            {"from": accounts[i]},
        )
        chain.sleep(50002)

        for n, acc in enumerate(accounts[:8]):
            if n != current_sale_owner:
                dai_contract.approve(
                    launch.return_value, 1000e18 * random_multiplier, {"from": acc}
                )
                BasicLaunch.at(launch.return_value).sendUSD(
                    1000e18 * random_multiplier, {"from": acc}
                )
