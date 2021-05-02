import brownie
import time
import constants
import pytest

'''
Configure tests
'''


def test_deployment_should_configure(running_launch, accounts, deployed_factory):
    market_contract = brownie.Market.at(running_launch.launchMarketAddress({'from': accounts[0]}))
    venture_bond_contract = running_launch.launchVentureBondAddress({'from': accounts[0]})
    assert market_contract.ventureBondContract({"from": accounts[0]}) == venture_bond_contract


def test_cannot_reconfigure_market(running_launch, accounts, deployed_factory):
    market_contract = brownie.Market.at(running_launch.launchMarketAddress({'from': accounts[0]}))
    venture_bond_contract = running_launch.launchVentureBondAddress({'from': accounts[0]})
    with brownie.reverts():
        market_contract.configure(venture_bond_contract, {'from': accounts[0]})


'''
Set Bid Shares tests
'''


def test_should_reject_if_set_bid_shares_from_non_venture_bond(running_launch, accounts, deployed_factory, send_any_stable_to_accounts):
    market_contract = brownie.Market.at(running_launch.launchMarketAddress({'from': accounts[0]}))
    with brownie.reverts("Market: Only ventureBond contract"):
        market_contract.setBidShares(0, [[0], [11e18], [89e18]], {'from': accounts[2]})


'''
Set Ask tests
'''


def test_should_reject_if_set_ask_from_non_venture_bond(running_launch, accounts, deployed_factory, send_any_stable_to_accounts):
    market_contract = brownie.Market.at(running_launch.launchMarketAddress({'from': accounts[0]}))
    with brownie.reverts("Market: Only ventureBond contract"):
        market_contract.setAsk(0, [constants.ASK_PRICE, send_any_stable_to_accounts.address], {'from': accounts[2]})



'''
Set Bid tests
'''


def test_should_reject_if_set_bid_from_non_venture_bond(running_launch, accounts, deployed_factory, send_any_stable_to_accounts):
    market_contract = brownie.Market.at(running_launch.launchMarketAddress({'from': accounts[0]}))
    with brownie.reverts("Market: Only ventureBond contract"):
        market_contract.setBid(0,
                                   [constants.BID_PRICE, send_any_stable_to_accounts.address, accounts[2], accounts[2], [0]]
                                   , accounts[2], {'from': accounts[2]})