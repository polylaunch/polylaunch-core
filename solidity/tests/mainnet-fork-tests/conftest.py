import pytest
import constants_mainnet as constants
import time
import brownie
from brownie import Contract
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

"""
For this to work you need to set up an infura id in your environmental variables

For it to work fast you need your ETHERSCAN_TOKEN api key in your environmental variables, log into etherscan and get an api key

https://eth-brownie.readthedocs.io/en/stable/network-management.html#using-infura 
(you could try out alchemy, Ive not tested it with brownie but i know its better than infura for hardhat)

RUN THIS from solidity dir
brownie test tests/mainnet-fork-tests --network mainnet-fork

add --interactive to debug any issues if the test fails

"""


@pytest.fixture(scope="function", autouse=True)
def isolate_func(fn_isolation):
    # perform a chain rewind after completing each test, to ensure proper isolation
    # https://eth-brownie.readthedocs.io/en/v1.10.3/tests-pytest-intro.html#isolation-fixtures
    pass


@pytest.fixture(scope="module", autouse=True)
def dai():
    yield Contract.from_explorer("0x6B175474E89094C44Da98b954EedeAC495271d0F")


@pytest.fixture(scope="module")
def cdai():
    yield Contract.from_explorer("0x5d3a536e4d6dbd6114cc1ead35777bab948e3643")


@pytest.fixture(scope="module")
def ydai():
    yield Contract.from_explorer("0x19D3364A399d251E894aC732651be8B0E4e85001")


@pytest.fixture(scope="module")
def adai():
    yield Contract.from_explorer("0x028171bCA77440897B824Ca71D1c56caC55b68A3")


@pytest.fixture(scope="module", autouse=True)
def uniswap_dai_exchange():
    yield Contract.from_explorer("0x2a1530C4C41db0B0b2bB646CB5Eb1A67b7158667")


@pytest.fixture(scope="module", autouse=True)
def gen_lev_farm_strat():
    yield Contract.from_explorer("0x4031afd3B0F71Bace9181E554A9E680Ee4AbE7dF")


@pytest.fixture(scope="function", autouse=True)
def send_10_eth_of_dai_to_accounts(accounts, dai, uniswap_dai_exchange):
    for account in accounts[:10]:
        uniswap_dai_exchange.ethToTokenSwapInput(
            1,  # minimum amount of tokens to purchase
            9999999999,  # timestamp
            {"from": account, "value": "10 ether"},
        )
    yield dai


@pytest.fixture(scope="function", autouse=True)
def deployed_factory(dai, accounts, cdai, ydai):
    deployer = accounts.at("0xC3D6880fD95E06C817cB030fAc45b3fae3651Cb0", force=True)

    constants_ = PolylaunchConstants.deploy({"from": deployer})
    registry = VentureBondDataRegistry.deploy({"from": deployer})
    utils = LaunchUtils.deploy({"from": deployer})
    redemption = LaunchRedemption.deploy({"from": deployer})
    logger = LaunchLogger.deploy({"from": deployer})
    governance = LaunchGovernance.deploy({"from": deployer})
    governor = GovernorAlpha.deploy({"from": deployer})
    launch = BasicLaunch.deploy({"from": deployer})
    system = PolylaunchSystem.deploy(
        dai.address,
        launch.address,
        governor.address,
        {"from": deployer},
    )
    auth = PolylaunchSystemAuthority.deploy(system.address, {"from": deployer})
    factory = LaunchFactory.at(
        system.tx.events["PolylaunchSystemLaunched"]["factoryAddress"]
    )
    vault_registry = PolyVaultRegistry.at(
        system.tx.events["PolylaunchSystemLaunched"]["vaultRegistry"]
    )
    system.registerNewVault(
        vault_registry.address, cdai.address, "COMPOUND_DAI", 1, {"from": deployer}
    )
    system.registerNewVault(
        vault_registry.address, ydai.address, "YEARN_VAULTS_DAI", 2, {"from": deployer}
    )
    system.registerNewVault(
        vault_registry.address,
        constants.AAVE_LENDING_POOL,
        "AAVE_LENDING_DAI",
        3,
        {"from": deployer},
    )
    accounts.remove(deployer)
    yield factory, system


@pytest.fixture(scope="function")
def mint_dummy_token(GovernableERC20, accounts):
    contract = GovernableERC20.deploy(
        accounts[0],
        accounts[0],
        chain.time() + 2000,
        "DummyToken",
        "TKN",
        constants.AMOUNT_FOR_SALE,
        {"from": accounts[0]},
    )
    yield contract


@pytest.fixture(scope="function")
def running_launch(mint_dummy_token, accounts, deployed_factory):
    deployed_factory, _ = deployed_factory
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
def successful_launch(running_launch, send_10_eth_of_dai_to_accounts, accounts):
    investor_accounts = accounts[1:10]

    # wait for it to start
    start_delta = constants.START_DATE - time.time()
    chain.sleep(int(start_delta) + 1)

    for account in investor_accounts:
        send_10_eth_of_dai_to_accounts.approve(
            running_launch, 1000e18, {"from": account}
        )
        running_launch.sendUSD(1000e18, {"from": account})

    chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)
    yield running_launch, send_10_eth_of_dai_to_accounts


@pytest.fixture(scope="function")
def success_launch_comp(successful_launch, send_10_eth_of_dai_to_accounts, accounts):
    launch_contract, usd_contract = successful_launch
    launch_contract.deposit(1, {"from": accounts[0]})
    yield launch_contract


@pytest.fixture(scope="function")
def success_launch_yearn(successful_launch, send_10_eth_of_dai_to_accounts, accounts):
    launch_contract, usd_contract = successful_launch
    launch_contract.deposit(2, {"from": accounts[0]})
    yield launch_contract


@pytest.fixture(scope="function")
def success_launch_aave(successful_launch, send_10_eth_of_dai_to_accounts, accounts):
    launch_contract, usd_contract = successful_launch
    launch_contract.deposit(3, {"from": accounts[0]})
    yield launch_contract


@pytest.fixture(scope="function")
def launch_with_succeeded_proposal(launch_with_active_tap_increase_proposal, accounts):
    proposal_id, launch, governor = launch_with_active_tap_increase_proposal

    investors = accounts[1:10]

    # Cast votes to make launch succeed
    for token_id, inv in enumerate(investors):
        governor.castVote(token_id, proposal_id, True, {"from": inv})

    chain.mine(20)  # Mine enough blocks to complete launch
    yield proposal_id, launch, governor


@pytest.fixture(scope="function")
def launch_with_queued_proposal(launch_with_succeeded_proposal, accounts):
    proposal_id, launch, governor = launch_with_succeeded_proposal

    governor.queue(proposal_id, {"from": accounts[0]})

    yield proposal_id, launch, governor


def get_governor(launch, sender):
    return GovernorAlpha.at(launch.governor({"from": sender}))


@pytest.fixture(params=["COMP", "YEARN", "AAVE"], scope="function")
def launch_with_active_tap_increase_proposal(
    request, successful_launch, accounts, gen_lev_farm_strat
):
    launch, _ = successful_launch
    if request.param == "COMP":
        launch.deposit(1, {"from": accounts[0]})
    elif request.param == "YEARN":
        launch.deposit(2, {"from": accounts[0]})
        keeper = brownie.accounts.at(
            "0xC3D6880fD95E06C816cB030fAc45b3ffe3651Cb0", force=True
        )
        chain.mine(1000)
        gen_lev_farm_strat.harvest({"from": keeper})
        brownie.accounts.remove(keeper)
    elif request.param == "AAVE":
        launch.deposit(3, {"from": accounts[0]})

    governor = get_governor(launch, accounts[0])
    launch_token_address = governor.launchToken({"from": accounts[1]})
    st = GovernableERC20.at(launch_token_address)
    chain.sleep(1000000)
    investors = accounts[1:10]

    for token_id, inv in enumerate(investors):
        launch.claim({"from": inv})
        st.delegate(inv.address, {"from": inv})

    tx = governor.proposeRefund(
        "Want a refund because reasons",
        0,
        {"from": accounts[0]},
    )

    chain.mine(2)
    yield tx.return_value, launch, governor
