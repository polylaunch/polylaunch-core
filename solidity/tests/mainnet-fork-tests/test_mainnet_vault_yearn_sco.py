import brownie
import time
import pytest
import constants_mainnet as constants

# this test represents a start to end scenario it shows that there will be funds left over at the end of the tap that
# must be exited. Once the dev exits they can access the generated funds by calling exitFromVault and then tapping
# these funds as normal. (Ydai value depends on the time you want to spend mining, note that rounding errors can
# occur during the tap)
def test_deposit_to_all_funds_withdrawn(successful_launch, accounts, ydai, gen_lev_farm_strat, deployed_factory):
    launch_contract, usd_contract = successful_launch
    initial_dai_balance = usd_contract.balanceOf(launch_contract.address)
    launch_contract.deposit(2, {"from": accounts[0]})
    initial_ydai_balance = ydai.balanceOf(launch_contract.address)
    initial_dai_own_balance = usd_contract.balanceOf(accounts[0])
    system_i_dai_balance = usd_contract.balanceOf(deployed_factory[1])

    keeper = brownie.accounts.at("0xC3D6880fD95E06C816cB030fAc45b3ffe3651Cb0", force=True)
    brownie.chain.mine(1000)
    gen_lev_farm_strat.harvest({"from": keeper})

    # brownie.chain.sleep(10000000000)
    tx = launch_contract.launcherTap({"from": accounts[0]})
    after_dai_balance = usd_contract.balanceOf(launch_contract.address)
    after_ydai_balance = ydai.balanceOf(launch_contract.address)
    after_dai_own_balance = usd_contract.balanceOf(accounts[0])

    assert initial_dai_balance > after_dai_balance
    assert initial_ydai_balance > after_ydai_balance
    assert initial_dai_own_balance < after_dai_own_balance
    assert after_dai_balance == 0
    assert after_ydai_balance != 0
    launch_contract.exitFromVault({"from": accounts[0]})
    system_a_dai_balance = usd_contract.balanceOf(deployed_factory[1])
    assert ydai.balanceOf(launch_contract.address) == 0
    assert system_i_dai_balance < system_a_dai_balance
    brownie.chain.sleep(10000000000)
    tx = launch_contract.launcherTap({"from": accounts[0]})
    assert "LauncherFundsTapped" in tx.events
    assert usd_contract.balanceOf(launch_contract.address) == 0
    with brownie.reverts("There are no funds to withdraw"):
        launch_contract.launcherTap({"from": accounts[0]})
    init_sys_owner_balance = usd_contract.balanceOf(accounts[0])
    deployed_factory[1].withdraw([usd_contract], accounts[0], {"from": accounts[0]})
    after_sys_owner_balance = usd_contract.balanceOf(accounts[0])
    assert init_sys_owner_balance < after_sys_owner_balance
    assert usd_contract.balanceOf(deployed_factory[1]) == 0

'''
Deposit scenarios
'''

def test_dev_deposit_yvDAI(successful_launch, accounts, dai, ydai):
    launch_contract, usd_contract = successful_launch
    initial_balance = dai.balanceOf(ydai.address)
    initial_ydai = ydai.balanceOf(launch_contract.address)
    tx = launch_contract.deposit(2, {"from": accounts[0]})
    assert "VaultFundsDeposited" in tx.events
    after_balance = dai.balanceOf(ydai.address)
    after_ydai = ydai.balanceOf(launch_contract.address)
    assert initial_ydai < after_ydai
    assert initial_balance < after_balance
    assert dai.balanceOf(launch_contract.address) == 0


def test_deposit_yearn_not_launcher(successful_launch, accounts):
    with brownie.reverts("Caller must be launcher"):
        successful_launch[0].deposit(2, {"from": accounts[1]})


def test_deposit_no_vault_id_reverts(successful_launch, accounts):
    launch_contract, _ = successful_launch
    with brownie.reverts("Vault: The selected vaultId is inactive"):
        launch_contract.deposit(99, {"from": accounts[0]})


def test_double_deposit_reverts(successful_launch, accounts):
    launch_contract, _ = successful_launch
    launch_contract.deposit(2, {"from": accounts[0]})
    with brownie.reverts("LaunchVault: Your funds are already in a vault pool"):
        launch_contract.deposit(2, {"from": accounts[0]})
    with brownie.reverts("LaunchVault: Your funds are already in a vault pool"):
        launch_contract.deposit(1, {"from": accounts[0]})


def test_deposit_empty_funds_reverts(successful_launch, accounts, cdai):
    launch_contract, usd_contract = successful_launch
    brownie.chain.sleep(10000000000)
    launch_contract.launcherTap({"from": accounts[0]})
    with brownie.reverts("LaunchVault: No funds to deposit into the Vault"):
        launch_contract.deposit(2, {"from": accounts[0]})


def test_deposit_exit_deposit_different(successful_launch, accounts, cdai, ydai, gen_lev_farm_strat):
    launch_contract, usd_contract = successful_launch
    launch_contract.deposit(2, {"from": accounts[0]})

    keeper = brownie.accounts.at("0xC3D6880fD95E06C816cB030fAc45b3ffe3651Cb0", force=True)
    brownie.chain.mine(1000)
    gen_lev_farm_strat.harvest({"from": keeper})

    launch_contract.exitFromVault({"from": accounts[0]})
    launch_contract.deposit(1, {"from": accounts[0]})
    assert usd_contract.balanceOf(launch_contract.address) == 0
    assert ydai.balanceOf(launch_contract.address) == 0
    assert cdai.balanceOf(launch_contract.address) > 0

'''
Tap Scenarios
'''


def test_dev_tap_yvDAI(successful_launch, accounts, ydai, dai):
    launch_contract, usd_contract = successful_launch
    initial_balance = dai.balanceOf(accounts[0], {"from": accounts[0]})
    tx = launch_contract.deposit(2, {"from": accounts[0]})

    brownie.chain.sleep(1000)

    launch_contract.launcherTap({"from": accounts[0]})
    timestamp_before = brownie.chain.time()
    second_balance = usd_contract.balanceOf(accounts[0], {"from": accounts[0]})
    assert second_balance > initial_balance

    brownie.chain.sleep(10000)

    tx = launch_contract.launcherTap({"from": accounts[0]})
    assert "VaultFundsTapped" in tx.events
    third_balance = usd_contract.balanceOf(accounts[0], {"from": accounts[0]})
    assert third_balance > second_balance


def test_tap_yearn_not_launcherlauncher(success_launch_yearn, accounts):
    with brownie.reverts("Caller must be launcher"):
        success_launch_yearn.launcherTap({"from": accounts[1]})


'''
Exit Scenarios
'''


def test_exit_vault_yearn(
        success_launch_yearn,
        accounts,
        ydai,
        send_10_eth_of_dai_to_accounts,
        deployed_factory,
        gen_lev_farm_strat
        ):
    deployed_factory, system = deployed_factory
    dai = send_10_eth_of_dai_to_accounts
    keeper = brownie.accounts.at("0xC3D6880fD95E06C816cB030fAc45b3ffe3651Cb0", force=True)
    brownie.chain.mine(10000)
    gen_lev_farm_strat.harvest({"from": keeper})

    initial_dai_balance = dai.balanceOf(success_launch_yearn.address)
    initial_ydai_balance = ydai.balanceOf(success_launch_yearn.address)

    tx = success_launch_yearn.exitFromVault({"from": accounts[0]})
    after_dai_balance = dai.balanceOf(success_launch_yearn.address)
    after_ydai_balance = ydai.balanceOf(success_launch_yearn.address)
    assert "VaultExited" in tx.events
    assert initial_dai_balance < after_dai_balance
    assert initial_ydai_balance > after_ydai_balance
    assert after_ydai_balance == 0
    system_dai_balance = dai.balanceOf(system.address)
    assert system_dai_balance != 0


def test_double_exit_attempt(successful_launch, accounts, deployed_factory, gen_lev_farm_strat):
    launch_contract, usd_contract = successful_launch
    launch_contract.deposit(2, {"from": accounts[0]})

    keeper = brownie.accounts.at("0xC3D6880fD95E06C816cB030fAc45b3ffe3651Cb0", force=True)
    brownie.chain.mine(1000)
    gen_lev_farm_strat.harvest({"from": keeper})
    launch_contract.exitFromVault({"from": accounts[0]})
    with brownie.reverts("LaunchVault: Yield has not been activated"):
        launch_contract.exitFromVault({"from": accounts[0]})
    assert usd_contract.balanceOf(deployed_factory[1]) > 0


def test_exit_yearn_not_launcher(success_launch_yearn, accounts):
    with brownie.reverts("Caller must be launcher"):
        success_launch_yearn.exitFromVault({"from": accounts[1]})




