import brownie
import time
import constants
import pytest
import random

'''
Mint Tests
'''


def test_mint_an_nft(successful_launch, accounts, deployed_factory):
    investors = accounts[1:]
    launch_contract, usd_contract = successful_launch
    venture_bond_address = launch_contract.launchVentureBondAddress({"from": accounts[0]})
    venture_bond_contract = brownie.VentureBond.at(venture_bond_address)
    for n, inv in enumerate(investors):
        tx = launch_contract.claim({"from": inv})

        assert "TokenMinted" in tx.events
        token_id = tx.events["TokenMinted"]["_tokenId"]
        assert token_id == n
        assert venture_bond_contract.balanceOf(inv, {"from": inv}) == 1
        assert venture_bond_contract.ownerOf(token_id, {"from": inv}) == inv
        assert venture_bond_contract.tokenCreators(token_id, {"from": inv}) == \
               deployed_factory.polylaunchSystemAddress({"from": accounts[0]})
        assert venture_bond_contract.previousTokenOwners(token_id, {"from": inv}) == \
               deployed_factory.polylaunchSystemAddress({"from": accounts[0]})
        assert venture_bond_contract.lastWithdrawnTime(token_id, {"from": inv}) == constants.END_DATE
        assert venture_bond_contract.tapRate(token_id, {"from": inv}) == constants.INITIAL_INV_TAP_RATE
        assert round(int(venture_bond_contract.tappableBalance(
            token_id, {"from": inv})), int(-13)) == round(int(((constants.AMOUNT_FOR_SALE) / len(investors))), int(-13))
        print(venture_bond_contract.tappableBalance(token_id, {"from": inv}),
              constants.AMOUNT_FOR_SALE / len(investors))
        print(venture_bond_contract.votingPower(token_id, {"from": inv}), constants.AMOUNT_FOR_SALE / len(investors))
        assert round(int(venture_bond_contract.votingPower(
            token_id, {"from": inv})), int(-13)) == round(int(((constants.AMOUNT_FOR_SALE) / len(investors))), int(-13))
        assert venture_bond_contract.tokenURI(token_id, {"from": inv}) == constants.GENERIC_NFT_DATA[0]
        assert venture_bond_contract.tokenMetadataURI(token_id, {"from": inv}) == constants.GENERIC_NFT_DATA[1]
        assert "0x" + constants.GENERIC_NFT_DATA[2] == \
               venture_bond_contract.tokenContentHashes(token_id, {"from": inv})
        assert venture_bond_contract.tokenMetadataHashes(token_id, {"from": inv}) == \
               "0x" + constants.GENERIC_NFT_DATA[3]


def test_set_nft_data_and_mint(successful_launch, accounts, deployed_factory):
    special_investor = accounts[1]
    non_special_investor = accounts[2]
    launch_contract, usd_contract = successful_launch
    venture_bond_address = launch_contract.launchVentureBondAddress({"from": accounts[0]})
    venture_bond_contract = brownie.VentureBond.at(venture_bond_address)
    launch_contract.setNftDataByTokenId(0, constants.SPECIAL_NFT_DATA, {'from': accounts[0]})
    launch_contract.claim({'from': special_investor})
    launch_contract.claim({'from': non_special_investor})
    assert venture_bond_contract.tokenURI(0, {"from": special_investor}) == constants.SPECIAL_NFT_DATA[0]
    assert venture_bond_contract.tokenMetadataURI(0, {"from": special_investor}) == constants.SPECIAL_NFT_DATA[1]
    assert "0x" + constants.SPECIAL_NFT_DATA[2] == \
           venture_bond_contract.tokenContentHashes(0, {"from": special_investor})
    assert venture_bond_contract.tokenMetadataHashes(0, {"from": special_investor}) == \
           "0x" + constants.SPECIAL_NFT_DATA[3]
    assert venture_bond_contract.tokenURI(1, {"from": special_investor}) == constants.GENERIC_NFT_DATA[0]
    assert venture_bond_contract.tokenMetadataURI(1, {"from": special_investor}) == constants.GENERIC_NFT_DATA[1]
    assert "0x" + constants.GENERIC_NFT_DATA[2] == \
           venture_bond_contract.tokenContentHashes(1, {"from": special_investor})
    assert venture_bond_contract.tokenMetadataHashes(1, {"from": special_investor}) == \
           "0x" + constants.GENERIC_NFT_DATA[3]


def test_batch_set_nft_data_and_mint(successful_launch, accounts, deployed_factory):
    special_investors = accounts[1:6]
    non_special_investor = accounts[7]
    launch_contract, usd_contract = successful_launch
    venture_bond_address = launch_contract.launchVentureBondAddress({"from": accounts[0]})
    venture_bond_contract = brownie.VentureBond.at(venture_bond_address)
    launch_contract.batchSetNftDataByTokenId([0, 1, 2, 3, 4], constants.BATCH_SPECIAL_NFT_DATA, {'from': accounts[0]})
    for n, inv in enumerate(special_investors):
        launch_contract.claim({'from': inv})
        assert venture_bond_contract.tokenURI(n, {"from": inv}) == constants.BATCH_SPECIAL_NFT_DATA[n][0]
        assert venture_bond_contract.tokenMetadataURI(n, {"from": inv}) == constants.BATCH_SPECIAL_NFT_DATA[n][1]
        assert "0x" + constants.BATCH_SPECIAL_NFT_DATA[n][2] == \
               venture_bond_contract.tokenContentHashes(n, {"from": inv})
        assert venture_bond_contract.tokenMetadataHashes(n, {"from": inv}) == \
               "0x" + constants.BATCH_SPECIAL_NFT_DATA[n][3]
    launch_contract.claim({'from': non_special_investor})
    assert venture_bond_contract.tokenURI(5, {"from": non_special_investor}) == constants.GENERIC_NFT_DATA[0]
    assert venture_bond_contract.tokenMetadataURI(5, {"from": non_special_investor}) == constants.GENERIC_NFT_DATA[1]
    assert "0x" + constants.GENERIC_NFT_DATA[2] == \
           venture_bond_contract.tokenContentHashes(5, {"from": non_special_investor})
    assert venture_bond_contract.tokenMetadataHashes(5, {"from": non_special_investor}) == \
           "0x" + constants.GENERIC_NFT_DATA[3]


def test_cannot_mint_manually(successful_launch, accounts):
    launch_contract, usd_contract = successful_launch
    venture_bond_address = launch_contract.launchVentureBondAddress({"from": accounts[0]})
    venture_bond_contract = brownie.VentureBond.at(venture_bond_address)

    with brownie.reverts("VentureBond: Only launch contract"):
        venture_bond_contract.mint([
            "PolyNFT",
            "PolyNFT",
            random.randint(1, 1000000),
            random.randint(1, 1000000),
            constants.INITIAL_INV_TAP_RATE,
            constants.END_DATE,
            999999999,
            0],
            [[0e18], [90e18], [10e18]], accounts[1], {"from": accounts[0]})


'''
Set ask Tests
'''


def test_should_set_ask(minted_launch, accounts, send_1000_usd_to_accounts):
    investors = accounts[1:]
    launch_contract, venture_bond_contract = minted_launch
    market_addr = launch_contract.launchMarketAddress({'from': accounts[0]})
    market_contract = brownie.Market.at(market_addr)
    for n, inv in enumerate(investors):
        tx = venture_bond_contract.setAsk(n, [constants.ASK_PRICE, send_1000_usd_to_accounts.address], {'from': inv})
        assert "AskCreated" in tx.events
        assert market_contract.currentAskForToken(n, {'from': accounts[0]})[0] == constants.ASK_PRICE
        assert market_contract.currentAskForToken(n, {'from': accounts[0]})[1] == send_1000_usd_to_accounts.address


def test_should_reject_if_ask_is_0(minted_launch, accounts, send_1000_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch

    with brownie.reverts('Market: Ask invalid for share splitting'):
        venture_bond_contract.setAsk(0, [0, send_1000_usd_to_accounts.address], {'from': accounts[1]})


def test_should_reject_if_ask_amount_is_invalid_and_cannot_be_split(minted_launch, accounts, send_1000_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch

    with brownie.reverts('Market: Ask invalid for share splitting'):
        venture_bond_contract.setAsk(0, [101, send_1000_usd_to_accounts.address], {'from': accounts[1]})


def test_should_reject_if_non_token_owner_sets_ask(minted_launch, accounts, send_1000_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch

    with brownie.reverts('VentureBond: Only approved or owner'):
        venture_bond_contract.setAsk(0, [constants.ASK_PRICE, send_1000_usd_to_accounts.address], {'from': accounts[2]})


'''
Remove ask Tests
'''


def test_should_remove_the_ask(minted_launch, accounts, send_1000_usd_to_accounts):
    investors = accounts[1:]
    launch_contract, venture_bond_contract = minted_launch
    market_addr = launch_contract.launchMarketAddress({'from': accounts[0]})
    market_contract = brownie.Market.at(market_addr)

    for n, inv in enumerate(investors):
        venture_bond_contract.setAsk(n, [constants.ASK_PRICE, send_1000_usd_to_accounts.address], {'from': inv})
        tx = venture_bond_contract.removeAsk(n, {'from': inv})

        assert "AskRemoved" in tx.events
        assert market_contract.currentAskForToken(n, {'from': accounts[0]})[0] == 0
        assert market_contract.currentAskForToken(n, {'from': accounts[0]})[1] == constants.ZERO_ADDRESS


def test_should_reject_if_non_token_owner_removes_ask(minted_launch, accounts, send_1000_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    venture_bond_contract.setAsk(0, [constants.ASK_PRICE, send_1000_usd_to_accounts.address], {'from': accounts[1]})

    with brownie.reverts("VentureBond: Only approved or owner"):
        venture_bond_contract.removeAsk(0, {'from': accounts[2]})


'''
Set Bid Tests
'''


def test_should_revert_if_bidder_not_high_enough_allowance_of_bid_currency(minted_launch,
                                                                           accounts,
                                                                           send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    bidder = accounts[2]

    with brownie.reverts("ERC20: transfer amount exceeds allowance"):
        venture_bond_contract.setBid(0,
                                  [constants.BID_PRICE, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                                  , {'from': bidder})


def test_should_revert_if_bidder_not_enough_balance_of_bid_currency(minted_launch,
                                                                    accounts,
                                                                    send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    token_for_launch = launch_contract.tokenForLaunch({"from": accounts[0]})
    market_contract = brownie.Market.at(launch_contract.launchMarketAddress({"from": accounts[0]}))
    token_contract = brownie.GovernableERC20.at(token_for_launch)
    bidder = accounts[2]
    send_any_usd_to_accounts.increaseAllowance(market_contract, 99999e18, {"from": bidder})

    with brownie.reverts("ERC20: transfer amount exceeds balance"):
        venture_bond_contract.setBid(0,
                                  [99999e18, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                                  , {'from': bidder})


def test_should_set_a_bid(minted_launch, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    market_contract = brownie.Market.at(launch_contract.launchMarketAddress({"from": accounts[0]}))
    bidder = accounts[2]
    send_any_usd_to_accounts.increaseAllowance(market_contract, constants.BID_PRICE, {"from": bidder})
    tx = venture_bond_contract.setBid(0,
                                   [constants.BID_PRICE, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                                   , {'from': bidder})

    assert "BidCreated" in tx.events
    assert send_any_usd_to_accounts.balanceOf(bidder, {"from": bidder}) == (constants.USD_AMOUNT - constants.BID_PRICE)


def test_should_automatically_transfer_nft_if_ask_set(minted_launch, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    market_contract = brownie.Market.at(launch_contract.launchMarketAddress({"from": accounts[0]}))
    bidder = accounts[2]
    nft_owner = accounts[1]
    nft_owner_dai_balance = send_any_usd_to_accounts.balanceOf(nft_owner, {"from": nft_owner})
    send_any_usd_to_accounts.increaseAllowance(market_contract, constants.ASK_PRICE, {"from": bidder})
    venture_bond_contract.setAsk(0, [constants.ASK_PRICE, send_any_usd_to_accounts.address], {'from': nft_owner})
    venture_bond_contract.setBid(0,
                              [constants.ASK_PRICE, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                              , {'from': bidder})

    assert venture_bond_contract.ownerOf(0, {"from": bidder}) == bidder
    assert send_any_usd_to_accounts.balanceOf(nft_owner, {"from": nft_owner}) == nft_owner_dai_balance + (
            constants.ASK_PRICE * 0.9)


def test_should_refund_bid_if_one_exists_from_bidder(minted_launch, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    market_contract = brownie.Market.at(launch_contract.launchMarketAddress({"from": accounts[0]}))
    bidder = accounts[2]
    send_any_usd_to_accounts.increaseAllowance(market_contract, constants.ASK_PRICE, {"from": bidder})
    venture_bond_contract.setBid(0,
                              [constants.ASK_PRICE - 100e18, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                              , {'from': bidder})
    bidder_balance_before = send_any_usd_to_accounts.balanceOf(bidder, {"from": bidder})
    send_any_usd_to_accounts.increaseAllowance(market_contract, constants.ASK_PRICE, {"from": bidder})
    tx = venture_bond_contract.setBid(0,
                                   [constants.ASK_PRICE, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                                   , {'from': bidder})

    assert send_any_usd_to_accounts.balanceOf(bidder, {"from": bidder}) == bidder_balance_before - 100e18
    assert tx.events["BidCreated"]["bid"]["amount"] == constants.ASK_PRICE


'''
Remove Bid Tests
'''


def test_should_revert_if_bidder_not_placed_a_bid(minted_launch, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    bidder = accounts[2]

    with brownie.reverts("Market: cannot remove bid amount of 0"):
        venture_bond_contract.removeBid(0, {'from': bidder})


def test_should_revert_if_token_id_not_created(minted_launch, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    bidder = accounts[2]

    with brownie.reverts("VentureBond: token with that id does not exist"):
        venture_bond_contract.removeBid(100, {'from': bidder})


def test_should_remove_bid_and_refund_bidder(minted_launch_with_bid, accounts, send_any_usd_to_accounts):
    bidder = accounts[2]
    launch_contract, venture_bond_contract = minted_launch_with_bid
    bidder_balance_before = send_any_usd_to_accounts.balanceOf(bidder, {"from": bidder})
    tx = venture_bond_contract.removeBid(0, {'from': bidder})

    assert "BidRemoved" in tx.events
    assert send_any_usd_to_accounts.balanceOf(bidder, {"from": bidder}) == bidder_balance_before + constants.BID_PRICE


def test_should_not_be_able_to_remove_bid_twice(minted_launch_with_bid, accounts, send_any_usd_to_accounts):
    bidder = accounts[2]
    launch_contract, venture_bond_contract = minted_launch_with_bid
    venture_bond_contract.removeBid(0, {'from': bidder})

    with brownie.reverts("Market: cannot remove bid amount of 0"):
        venture_bond_contract.removeBid(0, {'from': bidder})


'''
Burn Tests
'''


def test_should_revert_burn_even_if_owner(minted_launch_with_bid, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch_with_bid
    nft_owner = accounts[1]
    with brownie.reverts("VentureBond: owner is not creator of the VentureBond"):
        venture_bond_contract.burn(0, {'from': nft_owner})


'''
Accept Bid Tests
'''


def test_should_accept_bid(minted_launch_with_bid, accounts, send_any_usd_to_accounts, deployed_factory):
    launch_contract, venture_bond_contract = minted_launch_with_bid
    bidder = accounts[2]
    nft_owner = accounts[1]
    nft_owner_before_balance = send_any_usd_to_accounts.balanceOf(nft_owner, {"from": nft_owner})
    polylaunch_system_addr = deployed_factory.polylaunchSystemAddress({"from": accounts[0]})
    polylaunch_before_balance = send_any_usd_to_accounts.balanceOf(
        polylaunch_system_addr, {"from": accounts[0]})
    tx = venture_bond_contract.acceptBid(0, [constants.BID_PRICE, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                                      , {'from': nft_owner})
    nft_owner_after_balance = send_any_usd_to_accounts.balanceOf(nft_owner, {"from": nft_owner})
    polylaunch_after_balance = send_any_usd_to_accounts.balanceOf(polylaunch_system_addr, {"from": accounts[0]})

    assert "BidFinalized" in tx.events
    assert "BidShareUpdated" in tx.events
    assert nft_owner_after_balance == nft_owner_before_balance + constants.BID_PRICE * 0.9
    assert polylaunch_after_balance == polylaunch_before_balance + constants.BID_PRICE * 0.1
    assert venture_bond_contract.ownerOf(0, {'from': accounts[0]}) == bidder


def test_accept_bid_should_revert_if_not_owner(minted_launch_with_bid, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch_with_bid
    bidder = accounts[2]

    with brownie.reverts("VentureBond: Only approved or owner"):
        venture_bond_contract.acceptBid(0, [constants.BID_PRICE, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                                     , {'from': bidder})


def test_accept_bid_should_revert_if_bid_non_existent(minted_launch_with_bid, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch_with_bid
    bidder = accounts[2]
    nft_owner = accounts[1]

    with brownie.reverts("Market: Unexpected bid found."):
        venture_bond_contract.acceptBid(0, [0, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                                     , {'from': nft_owner})


def test_accept_bid_should_revert_if_invalid_bid_accepted(minted_launch, accounts, send_any_usd_to_accounts):
    launch_contract, venture_bond_contract = minted_launch
    bidder = accounts[2]
    nft_owner = accounts[1]
    market_contract = brownie.Market.at(launch_contract.launchMarketAddress({"from": accounts[0]}))
    send_any_usd_to_accounts.increaseAllowance(market_contract, 101, {"from": bidder})
    venture_bond_contract.setBid(0,
                              [101, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                              , {'from': bidder})

    with brownie.reverts("Market: Bid invalid for share splitting"):
        venture_bond_contract.acceptBid(0, [101, send_any_usd_to_accounts.address, bidder, bidder, [0]]
                                     , {'from': nft_owner})


'''
Transfer tests
'''


def test_should_remove_ask_after_transfer(minted_launch, accounts, send_any_usd_to_accounts):
    investors = accounts[1:]
    bidder = accounts[2]
    nft_owner = accounts[1]
    launch_contract, venture_bond_contract = minted_launch
    market_addr = launch_contract.launchMarketAddress({'from': accounts[0]})
    market_contract = brownie.Market.at(market_addr)

    for n, inv in enumerate(investors):
        venture_bond_contract.setAsk(n, [constants.ASK_PRICE, send_any_usd_to_accounts.address], {'from': inv})
    venture_bond_contract.transferFrom(nft_owner, bidder, 0, {'from': nft_owner})
    assert market_contract.currentAskForToken(0, {'from': accounts[0]})["amount"] == 0
    assert venture_bond_contract.ownerOf(0, {'from': accounts[0]}) == bidder


'''
Update tests
'''


# note: at time of writing 11/03 this value should be unchangeable, but the function is remaining open for future
# modifications if it can be changed anywhere else then a test case has been missed and this is a bug

def test_manual_token_uri_update_reverts(minted_launch, accounts):
    investors = accounts[1:]
    launch_contract, venture_bond_contract = minted_launch
    for n, inv in enumerate(investors):
        with brownie.reverts("VentureBond: Only launch contract"):
            venture_bond_contract.updateTokenURI(n, "TROLL", inv, {'from': inv})


# note: at time of writing 11/03 this value should be unchangeable, but the function is remaining open for future
# modifications if it can be changed anywhere else then a test case has been missed and this is a bug

def test_manual_token_metadata_update_reverts(minted_launch, accounts):
    investors = accounts[1:]
    launch_contract, venture_bond_contract = minted_launch
    for n, inv in enumerate(investors):
        with brownie.reverts("VentureBond: Only launch contract"):
            venture_bond_contract.updateTokenMetadataURI(n, "TROLL", inv, {'from': inv})


# note: it is VITAL, this should only be changed via increaseTap in BasicLaunch, if it can be changed
# anywhere else then a test case has been missed and this is a bug

def test_manual_tap_update_reverts(minted_launch, accounts):
    investors = accounts[1:]
    launch_contract, venture_bond_contract = minted_launch
    for n, inv in enumerate(investors):
        with brownie.reverts("VentureBond: Only launch contract"):
            venture_bond_contract.updateTapRate(n, 999999, inv, {'from': inv})


# note: it is VITAL, this should only be changed via investorTap in BasicLaunch, if it can be changed
# anywhere else then a test case has been missed and this is a bug

def test_manual_last_withdrawn_time_update_reverts(minted_launch, accounts):
    investors = accounts[1:]
    launch_contract, venture_bond_contract = minted_launch
    for n, inv in enumerate(investors):
        with brownie.reverts("VentureBond: Only launch contract"):
            venture_bond_contract.updateLastWithdrawnTime(n, 1, inv, {'from': inv})


# note: it is VITAL, this should only be changed via investorTap in BasicLaunch, if it can be changed
# anywhere else then a test case has been missed and this is a bug

def test_manual_tappable_balance_update_reverts(minted_launch, accounts):
    investors = accounts[1:]
    launch_contract, venture_bond_contract = minted_launch
    for n, inv in enumerate(investors):
        with brownie.reverts("VentureBond: Only launch contract"):
            venture_bond_contract.updateTappableBalance(n, 1, inv, {'from': inv})


# note: at time of writing 11/03 this value should be unchangeable, but the function is remaining open for future
# modifications if it can be changed anywhere else then a test case has been missed and this is a bug

def test_manual_voting_power_update_reverts(minted_launch, accounts):
    investors = accounts[1:]
    launch_contract, venture_bond_contract = minted_launch
    for n, inv in enumerate(investors):
        with brownie.reverts("VentureBond: Only launch contract"):
            venture_bond_contract.updateVotingPower(n, 9999999, inv, {'from': inv})
# TODO
#
# def tests_related_to_content_hash_etc_tbd
