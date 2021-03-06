#!/usr/bin/python3

import pytest
import time
import constants
from brownie.network.transaction import TransactionReceipt
from brownie.convert import to_address
from brownie import (
    LaunchRedemption,
    LaunchLogger,
    LaunchGovernance,
    LaunchFactory,
    BasicLaunch,
    BasicERC20,
    GovernableERC20,
    LaunchUtils,
    PolylaunchConstants,
    PolylaunchSystem,
    PolylaunchSystemAuthority,
    PreLaunchRegistry,
    VentureBond,
    Market,
    PolyVault,
    PolyVaultRegistry,
    GovernorAlpha,
    accounts,
    web3,
    Wei,
    chain,
    Contract,
)


@pytest.fixture(scope="module", autouse=True)
def deployed_factory(stable_contract, accounts):
    deployer = accounts.at("0xC3D6880fD95E06C817cB030fAc45b3fae3651Cb0", force=True)
    constants = PolylaunchConstants.deploy({"from": deployer})
    registry = PreLaunchRegistry.deploy({"from": deployer})
    utils = LaunchUtils.deploy({"from": deployer})
    redemption = LaunchRedemption.deploy({"from": deployer})
    logger = LaunchLogger.deploy({"from": deployer})
    governance = LaunchGovernance.deploy({"from": deployer})
    governor = GovernorAlpha.deploy({"from": deployer})
    launch = BasicLaunch.deploy({"from": deployer})
    system = PolylaunchSystem.deploy(
        stable_contract.address,
        launch.address,
        governor.address,
        {"from": deployer},
    )
    auth = PolylaunchSystemAuthority.deploy(system.address, {"from": deployer})
    factory = LaunchFactory.at(
        system.tx.events["PolylaunchSystemLaunched"]["factoryAddress"]
    )
    accounts.remove(deployer)
    yield factory


@pytest.fixture(scope="module", autouse=True)
def stable_contract(BasicERC20, accounts):
    contract = BasicERC20.deploy("Dai Stablecoin", "DAI", {"from": accounts[0]})
    yield contract


@pytest.fixture(scope="function", autouse=True)
def isolate_func(fn_isolation):
    # perform a chain rewind after completing each test, to ensure proper isolation
    # https://eth-brownie.readthedocs.io/en/v1.10.3/tests-pytest-intro.html#isolation-fixtures
    pass


@pytest.fixture(scope="function")
def mint_dummy_token(GovernableERC20, accounts):
    contract = GovernableERC20.deploy(
        accounts[0],
        accounts[0],
        chain.time() + 1000,
        "DummyToken",
        "TKN",
        constants.AMOUNT_FOR_SALE,
        {"from": accounts[0]},
    )
    yield contract


@pytest.fixture(scope="function")
def send_1000_stable_to_accounts(stable_contract, accounts):
    for account in accounts:
        stable_contract.mint(1000e18, {"from": account})
    yield stable_contract


@pytest.fixture(scope="function")
def send_any_stable_to_accounts(stable_contract, accounts):
    for account in accounts:
        stable_contract.mint(constants.stable_AMOUNT, {"from": account})
    yield stable_contract


@pytest.fixture(scope="function")
def alt_launch_minted(accounts, deployed_factory, send_any_stable_to_accounts):
    alt_coin = GovernableERC20.deploy(
        accounts[0],
        accounts[0],
        chain.time() + 1000,
        "DummyToken",
        "TKN",
        constants.AMOUNT_FOR_SALE,
        {"from": accounts[0]},
    )
    alt_coin.approve(deployed_factory, constants.AMOUNT_FOR_SALE, {"from": accounts[0]})
    launch = deployed_factory.createBasicLaunch(
        [
            accounts[0],
            alt_coin.address,
            constants.AMOUNT_FOR_SALE,
            constants.ALT_START_DATE,
            constants.ALT_END_DATE,
            constants.MINIMUM_FUNDING,
            constants.INITIAL_DEV_VESTING,
            constants.INITIAL_INV_VESTING,
            constants.INDIVIDUAL_FUNDING_CAP,
            constants.FIXED_SWAP_RATE,
            constants.GENERIC_NFT_DATA,
            constants.DUMMY_IPFS_HASH,
        ],
        {"from": accounts[0]},
    )
    launch = BasicLaunch.at(launch.return_value)
    investors = accounts[1:10]

    # wait for it to start
    start_delta = constants.START_DATE - time.time()
    chain.sleep(int(start_delta) + 1)
    launch.batchAddToWhitelist(investors, {"from": accounts[0]})
    for account in investors:
        send_any_stable_to_accounts.increaseAllowance(launch, 1000e18, {"from": account})
        launch.sendStable(1000e18, {"from": account})

    chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)

    venture_bond_address = launch.launchVentureBondAddress({"from": accounts[0]})
    nft = VentureBond.at(venture_bond_address)
    for inv in investors:
        launch.claim({"from": inv})

    yield launch, send_any_stable_to_accounts, nft


@pytest.fixture(scope="function")
def running_launch(mint_dummy_token, accounts, deployed_factory):
    mint_dummy_token.approve(
        deployed_factory, constants.AMOUNT_FOR_SALE, {"from": accounts[0]}
    )
    launch = deployed_factory.createBasicLaunch(
        [
            accounts[0],
            mint_dummy_token.address,
            constants.AMOUNT_FOR_SALE,
            constants.START_DATE,
            constants.END_DATE,
            constants.MINIMUM_FUNDING,
            constants.INITIAL_DEV_VESTING,
            constants.INITIAL_INV_VESTING,
            constants.INDIVIDUAL_FUNDING_CAP,
            constants.FIXED_SWAP_RATE,
            constants.GENERIC_NFT_DATA,
            constants.DUMMY_IPFS_HASH,
        ],
        {"from": accounts[0]},
    )
    yield BasicLaunch.at(launch.return_value)


@pytest.fixture(scope="function")
def successful_launch(running_launch, send_1000_stable_to_accounts, accounts):
    investor_accounts = accounts[1:10]

    # wait for it to start
    start_delta = constants.START_DATE - time.time()
    chain.sleep(int(start_delta) + 1)
    running_launch.batchAddToWhitelist(investor_accounts, {"from": accounts[0]})
    for account in investor_accounts:
        send_1000_stable_to_accounts.increaseAllowance(
            running_launch, 1000e18, {"from": account}
        )
        running_launch.sendStable(1000e18, {"from": account})

    chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)
    yield running_launch, send_1000_stable_to_accounts


@pytest.fixture(scope="function")
def failed_launch(running_launch, accounts):
    start_delta = constants.START_DATE - time.time()

    # Sleep until it finishes
    chain.sleep(int(start_delta) + 1)
    chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)

    yield running_launch


@pytest.fixture(scope="function")
def minted_launch(successful_launch, accounts):
    investors = accounts[1:10]
    launch_contract, stable_contract = successful_launch
    venture_bond_address = launch_contract.launchVentureBondAddress(
        {"from": accounts[0]}
    )
    venture_bond_contract = VentureBond.at(venture_bond_address)
    for n, inv in enumerate(investors):
        launch_contract.claim({"from": inv})

    yield launch_contract, venture_bond_contract


@pytest.fixture(scope="function")
def minted_launch_with_bid(minted_launch, accounts, send_any_stable_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    market_contract = Market.at(
        launch_contract.launchMarketAddress({"from": accounts[0]})
    )
    bidder = accounts[2]
    send_any_stable_to_accounts.increaseAllowance(
        market_contract, constants.BID_PRICE, {"from": bidder}
    )
    venture_bond_contract.setBid(
        0,
        [constants.BID_PRICE, send_any_stable_to_accounts.address, bidder, bidder, [0]],
        {"from": bidder},
    )

    yield launch_contract, venture_bond_contract
