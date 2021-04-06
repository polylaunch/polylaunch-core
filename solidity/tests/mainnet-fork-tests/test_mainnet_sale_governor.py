import brownie
import time
import constants_mainnet as constants
import pytest


def test_claim_refund_after_succeeded_proposal_succeeds_yearn(
    launch_with_queued_proposal, accounts, gen_lev_farm_strat, dai, ydai
):
    proposal_id, launch, governor = launch_with_queued_proposal
    if launch.selectedVaultProvider != 2:
        return
    current_tap_rate = launch.launcherTapRate({"from": accounts[0]})
    proposed_tap_rate = governor.proposals(proposal_id, {"from": accounts[0]})[
        "newRate"
    ]
    if proposed_tap_rate != 0:
        # it means it's a tap increase proposal. 0 is a default value. we aren't testing tap increase here
        return

    initial_dai_balance = dai.balanceOf(launch.address)
    initial_ydai_balance = ydai.balanceOf(launch.address)
    ydai_before_price = ydai.pricePerShare({"from": accounts[0]})

    brownie.chain.sleep(86400 + 1)  # just over 1 day
    governor.execute(proposal_id, {"from": accounts[0]})
    after_ydai_balance = ydai.balanceOf(launch.address)
    after_dai_balance = dai.balanceOf(launch.address)
    ydai_after_price = ydai.pricePerShare({"from": accounts[0]})
    print(initial_dai_balance, after_dai_balance, initial_ydai_balance, after_ydai_balance)
    print(ydai_before_price, ydai_after_price, ydai_before_price*initial_ydai_balance, ydai_after_price*after_ydai_balance)
    token_address = launch.tokenForLaunch({"from": accounts[1]})
    token_contract = brownie.GovernableERC20.at(token_address)
    assert after_dai_balance > 9000e18
    assert after_ydai_balance == 0

    tx = launch.claimRefund(0, {"from": accounts[1]})

    assert 1100e18 > tx.return_value > 1000e18

def test_claim_refund_after_succeeded_proposal_succeeds_comp(
    launch_with_queued_proposal, accounts, gen_lev_farm_strat, dai, cdai
):
    proposal_id, launch, governor = launch_with_queued_proposal
    if launch.selectedVaultProvider != 1:
        return
    current_tap_rate = launch.launcherTapRate({"from": accounts[0]})
    proposed_tap_rate = governor.proposals(proposal_id, {"from": accounts[0]})[
        "newRate"
    ]
    if proposed_tap_rate != 0:
        # it means it's a tap increase proposal. 0 is a default value. we aren't testing tap increase here
        return

    initial_dai_balance = dai.balanceOf(launch.address)
    initial_cdai_balance = cdai.balanceOf(launch.address)

    brownie.chain.sleep(86400 + 1)  # just over 1 day
    governor.execute(proposal_id, {"from": accounts[0]})
    after_cdai_balance = cdai.balanceOf(launch.address)
    after_dai_balance = dai.balanceOf(launch.address)
    print(initial_dai_balance, after_dai_balance, initial_cdai_balance, after_cdai_balance)
    token_address = launch.tokenForLaunch({"from": accounts[1]})
    token_contract = brownie.GovernableERC20.at(token_address)
    assert after_dai_balance > 9000e18
    assert after_cdai_balance == 0

    tx = launch.claimRefund(0, {"from": accounts[1]})

    assert 1100e18 > tx.return_value > 1000e18

def test_claim_refund_after_succeeded_proposal_succeeds_aave(
    launch_with_queued_proposal, accounts, gen_lev_farm_strat, dai, adai
):

    proposal_id, launch, governor = launch_with_queued_proposal
    if launch.selectedVaultProvider != 3:
        return
    current_tap_rate = launch.launcherTapRate({"from": accounts[0]})
    proposed_tap_rate = governor.proposals(proposal_id, {"from": accounts[0]})[
        "newRate"
    ]
    if proposed_tap_rate != 0:
        # it means it's a tap increase proposal. 0 is a default value. we aren't testing tap increase here
        return

    initial_dai_balance = dai.balanceOf(launch.address)
    initial_adai_balance = adai.balanceOf(launch.address)

    brownie.chain.sleep(86400 + 1)  # just over 1 day
    governor.execute(proposal_id, {"from": accounts[0]})
    after_adai_balance = adai.balanceOf(launch.address)
    after_dai_balance = dai.balanceOf(launch.address)
    print(initial_dai_balance, after_dai_balance, initial_adai_balance, after_adai_balance)
    token_address = launch.tokenForLaunch({"from": accounts[1]})
    token_contract = brownie.GovernableERC20.at(token_address)
    assert after_dai_balance > 9000e18
    assert after_adai_balance == 0

    tx = launch.claimRefund(0, {"from": accounts[1]})

    assert 1100e18 > tx.return_value > 1000e18