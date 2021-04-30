import brownie
import time
import pytest
import constants_mainnet as constants


# this test represents a start to end scenario it shows that there will be funds left over at the end of the tap that
# must be exited. Once the dev exits they can access the generated funds by calling exitFromVault and then tapping
# these funds as normal. (adai value depends on the time you want to spend mining)
def test_deposit_to_all_funds_withdrawn(successful_launch, accounts, adai, deployed_factory):
    launch_contract, usd_contract = successful_launch
    initial_dai_balance = usd_contract.balanceOf(launch_contract.address)
    launch_contract.deposit(3, {"from": accounts[0]})
    initial_adai_balance = adai.scaledBalanceOf(launch_contract.address)
    initial_dai_own_balance = usd_contract.balanceOf(accounts[0])
    system_i_dai_balance = usd_contract.balanceOf(deployed_factory[1])
    brownie.chain.sleep(10000000)
    brownie.chain.mine(1000)
    tx = launch_contract.launcherTap({"from": accounts[0]})
    after_dai_balance = usd_contract.balanceOf(launch_contract.address)
    after_adai_balance = adai.balanceOf(launch_contract.address)
    after_dai_own_balance = usd_contract.balanceOf(accounts[0])

    assert initial_dai_balance > after_dai_balance
    assert initial_adai_balance > after_adai_balance
    assert initial_dai_own_balance < after_dai_own_balance
    assert after_dai_balance == 0
    assert after_adai_balance != 0
    launch_contract.exitFromVault({"from": accounts[0]})
    system_a_dai_balance = usd_contract.balanceOf(deployed_factory[1])
    assert adai.balanceOf(launch_contract.address) == 0
    assert system_i_dai_balance < system_a_dai_balance
    brownie.chain.sleep(1000000000)
    tx = launch_contract.launcherTap({"from": accounts[0]})
    assert "LauncherFundsTapped" in tx.events
    assert usd_contract.balanceOf(launch_contract.address) == 0
    with brownie.reverts("There are no funds to withdraw"):
        launch_contract.launcherTap({"from": accounts[0]})
    init_sys_owner_balance = usd_contract.balanceOf(accounts[0])
    deployed_factory[1].withdraw([usd_contract], accounts[0], {"from": accounts.at("0xC3D6880fD95E06C817cB030fAc45b3fae3651Cb0", force=True)})
    after_sys_owner_balance = usd_contract.balanceOf(accounts[0])
    assert init_sys_owner_balance < after_sys_owner_balance
    assert usd_contract.balanceOf(deployed_factory[1]) == 0


'''
Deposit scenarios
'''


def test_dev_deposit_aave(successful_launch, accounts, dai, adai):
    launch_contract, usd_contract = successful_launch
    initial_balance = dai.balanceOf(adai.address)
    initial_adai = adai.balanceOf(launch_contract.address)

    tx = launch_contract.deposit(3, {"from": accounts[0]})

    after_balance = dai.balanceOf(adai.address)
    after_adai = adai.balanceOf(launch_contract.address)

    assert "VaultFundsDeposited" in tx.events
    assert initial_adai < after_adai
    assert initial_balance < after_balance
    assert dai.balanceOf(launch_contract.address) == 0



def test_deposit_aave_not_launcher(successful_launch, accounts):
    with brownie.reverts("Caller must be launcher"):
        successful_launch[0].deposit(3, {"from": accounts[1]})


def test_deposit_no_vault_id_reverts(successful_launch, accounts):
    launch_contract, _ = successful_launch
    with brownie.reverts("Vault: The selected vaultId is inactive"):
        launch_contract.deposit(99, {"from": accounts[0]})


def test_double_deposit_reverts(successful_launch, accounts):
    launch_contract, _ = successful_launch
    launch_contract.deposit(3, {"from": accounts[0]})
    with brownie.reverts("LaunchVault: Your funds are already in a vault pool"):
        launch_contract.deposit(3, {"from": accounts[0]})
    with brownie.reverts("LaunchVault: Your funds are already in a vault pool"):
        launch_contract.deposit(2, {"from": accounts[0]})


def test_deposit_empty_funds_reverts(successful_launch, accounts, adai):
    launch_contract, usd_contract = successful_launch
    brownie.chain.sleep(10000000000)
    launch_contract.launcherTap({"from": accounts[0]})
    with brownie.reverts("LaunchVault: No funds to deposit into the Vault"):
        launch_contract.deposit(3, {"from": accounts[0]})


def test_deposit_exit_deposit_different(successful_launch, accounts, adai, ydai, deployed_factory):
    launch_contract, usd_contract = successful_launch
    launch_contract.deposit(3, {"from": accounts[0]})
    brownie.chain.sleep(10000)
    launch_contract.exitFromVault({"from": accounts[0]})
    launch_contract.deposit(2, {"from": accounts[0]})
    assert usd_contract.balanceOf(launch_contract.address) == 0
    assert ydai.balanceOf(launch_contract.address) > 0
    assert adai.balanceOf(launch_contract.address) == 0
    assert usd_contract.balanceOf(deployed_factory[1]) > 0


'''
Tap Scenarios
'''


def test_dev_tap_aave(successful_launch, accounts, adai, dai):
    launch_contract, usd_contract = successful_launch
    initial_balance = dai.balanceOf(accounts[0], {"from": accounts[0]})
    launch_contract.deposit(3, {"from": accounts[0]})
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


def test_tap_aave_not_launcher(success_launch_aave, accounts):
    with brownie.reverts("Caller must be launcher"):
        success_launch_aave.launcherTap({"from": accounts[1]})


'''
Exit Scenarios
'''


def test_exit_vault_aave(success_launch_aave, accounts, adai, send_10_eth_of_dai_to_accounts, deployed_factory):
    deployed_factory, system = deployed_factory
    dai = send_10_eth_of_dai_to_accounts
    initial_dai_balance = dai.balanceOf(success_launch_aave.address)
    initial_adai_balance = adai.balanceOf(success_launch_aave.address)
    brownie.chain.mine(100)
    tx = success_launch_aave.exitFromVault({"from": accounts[0]})
    after_dai_balance = dai.balanceOf(success_launch_aave.address)
    after_adai_balance = adai.balanceOf(success_launch_aave.address)
    assert "VaultExited" in tx.events
    assert initial_dai_balance < after_dai_balance
    assert initial_adai_balance > after_adai_balance
    assert after_adai_balance == 0
    system_dai_balance = dai.balanceOf(system.address)
    assert system_dai_balance != 0


def test_double_exit_attempt(successful_launch, accounts, deployed_factory):
    launch_contract, usd_contract = successful_launch
    launch_contract.deposit(3, {"from": accounts[0]})
    brownie.chain.sleep(1000)
    launch_contract.exitFromVault({"from": accounts[0]})
    with brownie.reverts("LaunchVault: Yield has not been activated"):
        launch_contract.exitFromVault({"from": accounts[0]})
    assert usd_contract.balanceOf(deployed_factory[1]) > 0


def test_exit_aave_not_launcher(success_launch_aave, accounts):
    with brownie.reverts("Caller must be launcher"):
        success_launch_aave.exitFromVault({"from": accounts[1]})
