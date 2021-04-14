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
    VentureBondDataRegistry,
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
def deployed_factory(usd_contract, accounts):
    deployer = accounts.at("0xC3D6880fD95E06C817cB030fAc45b3fae3651Cb0", force=True)
    constants = PolylaunchConstants.deploy({"from": deployer})
    registry = VentureBondDataRegistry.deploy({"from": deployer})
    utils = LaunchUtils.deploy({"from": deployer})
    redemption = LaunchRedemption.deploy({"from": deployer})
    logger = LaunchLogger.deploy({"from": deployer})
    governance = LaunchGovernance.deploy({"from": deployer})
    governor = GovernorAlpha.deploy({"from": deployer})
    market = Market.deploy({"from": deployer})
    launch = BasicLaunch.deploy({"from": deployer})
    system = PolylaunchSystem.deploy(
        usd_contract.address,
        launch.address,
        governor.address,
        market.address,
        {"from": deployer},
    )
    auth = PolylaunchSystemAuthority.deploy(system.address, {"from": deployer})
    factory = LaunchFactory.at(
        system.tx.events["PolylaunchSystemLaunched"]["factoryAddress"]
    )
    accounts.remove(deployer)
    yield factory

@pytest.fixture(scope="module", autouse=True)
def usd_contract(BasicERC20, accounts):
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
def send_1000_usd_to_accounts(usd_contract, accounts):
    for account in accounts:
        usd_contract.mint(1000e18, {"from": account})
    yield usd_contract


@pytest.fixture(scope="function")
def send_any_usd_to_accounts(usd_contract, accounts):
    for account in accounts:
        usd_contract.mint(constants.USD_AMOUNT, {"from": account})
    yield usd_contract


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
            constants.INITIAL_DEV_TAP_RATE,
            constants.INITIAL_INV_TAP_RATE,
            constants.FUNDING_CAP,
            constants.INDIVIDUAL_FUNDING_CAP,
            constants.FIXED_SWAP_RATE,
            constants.NFT_NAME,
            constants.NFT_SYMBOL,
            constants.GENERIC_NFT_DATA,
        ],
        {"from": accounts[0]},
    )
    yield BasicLaunch.at(launch.return_value)


@pytest.fixture(scope="function")
def successful_launch(running_launch, send_1000_usd_to_accounts, accounts):
    investor_accounts = accounts[1:]

    # wait for it to start
    start_delta = constants.START_DATE - time.time()
    chain.sleep(int(start_delta) + 1)

    for account in investor_accounts:
        send_1000_usd_to_accounts.increaseAllowance(
            running_launch, 1000e18, {"from": account}
        )
        running_launch.sendUSD(1000e18, {"from": account})

    chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)
    yield running_launch, send_1000_usd_to_accounts


@pytest.fixture(scope="function")
def failed_launch(running_launch, accounts):
    start_delta = constants.START_DATE - time.time()

    # Sleep until it finishes
    chain.sleep(int(start_delta) + 1)
    chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)

    yield running_launch


@pytest.fixture(scope="function")
def minted_launch(successful_launch, accounts):
    investors = accounts[1:]
    launch_contract, usd_contract = successful_launch
    venture_bond_address = launch_contract.launchVentureBondAddress({"from": accounts[0]})
    venture_bond_contract = VentureBond.at(venture_bond_address)
    for n, inv in enumerate(investors):
        launch_contract.claim({"from": inv})

    yield launch_contract, venture_bond_contract


@pytest.fixture(scope="function")
def minted_launch_with_bid(minted_launch, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    market_contract = Market.at(launch_contract.launchMarketAddress({"from": accounts[0]}))
    bidder = accounts[2]
    send_any_usd_to_accounts.increaseAllowance(
        market_contract, constants.BID_PRICE, {"from": bidder}
    )
    venture_bond_contract.setBid(
        0,
        [constants.BID_PRICE, send_any_usd_to_accounts.address, bidder, bidder, [0]],
        {"from": bidder},
    )

    yield launch_contract, venture_bond_contract
