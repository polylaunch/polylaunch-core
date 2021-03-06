import brownie
import time
import constants
import pytest


def test_alt_launch(minted_launch, alt_launch_minted, accounts):
    alt_launch, stable, nft = alt_launch_minted
    launch, _ = minted_launch
    nft_main_id = 0
    nft_alt_id = 9
    assert nft.ownerOf(nft_main_id) == accounts[1]
    assert nft.ownerOf(nft_alt_id) == accounts[1]
    assert nft.launchAddressAssociatedWithToken(nft_main_id) == launch.address
    assert nft.launchAddressAssociatedWithToken(nft_alt_id) == alt_launch.address
    with brownie.reverts("supporterTap: ventureBond not associated with this launch"):
        launch.supporterTap(nft_alt_id, {"from": accounts[1]})
        alt_launch.supporterTap(nft_main_id, {"from": accounts[1]})
    with brownie.reverts("Not your ventureBond"):
        launch.supporterTap(nft_main_id, {"from": accounts[2]})
        alt_launch.supporterTap(nft_alt_id, {"from": accounts[2]})
    assert launch.supporterTap(nft_main_id, {"from": accounts[1]})
    assert alt_launch.supporterTap(nft_alt_id, {"from": accounts[1]})


def test_create_basic_launch(mint_dummy_token, deployed_factory, accounts):
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
    assert len(str(launch.return_value)) == 42
    assert "BasicLaunchCreated" in launch.events

    launch_contract = brownie.BasicLaunch.at(launch.return_value)
    assert (
        launch_contract.launchStartTime({"from": accounts[1]}) == constants.START_DATE
    )
    assert launch_contract.launchEndTime({"from": accounts[1]}) == constants.END_DATE
    assert mint_dummy_token.balanceOf(launch_contract) == constants.AMOUNT_FOR_SALE


def test_create_basic_launch_fails_with_bad_nft_data(
    mint_dummy_token, deployed_factory, accounts
):
    mint_dummy_token.approve(
        deployed_factory, constants.AMOUNT_FOR_SALE, {"from": accounts[0]}
    )
    for nftData in constants.FAILURE_NFT_DATA:
        # various different error conditions, them all failing is ok, as the variables are independent
        with brownie.reverts():
            deployed_factory.createBasicLaunch(
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
                    nftData,
                    constants.DUMMY_IPFS_HASH,
                ],
                {"from": accounts[0]},
            )


def test_setting_bad_nft_data_should_fail(running_launch, accounts):
    # various different error conditions, them all failing is ok, as the variables are independent
    for nftData in constants.FAILURE_NFT_DATA:
        with brownie.reverts():
            running_launch.setNftDataByIndex(0, nftData, {"from": accounts[0]})
    with brownie.reverts():
        running_launch.batchSetNftDataByIndex(
            [0, 1, 2], constants.FAILURE_NFT_DATA, {"from": accounts[0]}
        )
        

def test_no_send_if_not_whitelisted(
    running_launch, accounts, send_1000_stable_to_accounts
):
    investors = accounts[2:10]
    start_delta = constants.START_DATE - time.time()
    running_launch.batchAddToWhitelist(investors, {"from": accounts[0]})
    brownie.chain.sleep(int(start_delta) + 1)
    send_1000_stable_to_accounts.increaseAllowance(
        running_launch, constants.LOW_INPUT_AMOUNT, {"from": accounts[1]}
    )
    with brownie.reverts("msg.sender not whitelisted"):
        running_launch.sendStable(constants.LOW_INPUT_AMOUNT, {"from": accounts[1]})

    

def test_receive_stable_from_same_twice(
    running_launch, send_1000_stable_to_accounts, accounts
):
    stable_contract = send_1000_stable_to_accounts
    investors = accounts[1:4]
    start_time = running_launch.launchStartTime({"from": accounts[1]})
    end_time = running_launch.launchEndTime({"from": accounts[1]})
    running_launch.batchAddToWhitelist(investors, {"from": accounts[0]})
    start_delta = start_time - time.time() + 1
    brownie.chain.sleep(start_delta)
    running_launch.batchSetNftDataByIndex(
        [0, 1, 2, 3, 4], constants.BATCH_SPECIAL_NFT_DATA, {"from": accounts[0]}
    )
    delta = int((end_time - start_time))
    stable_contract.increaseAllowance(running_launch, 500e18, {"from": accounts[1]})
    running_launch.sendStable(500e18, {"from": accounts[1]})
    for inv in investors:
        stable_contract.increaseAllowance(running_launch, 500e18, {"from": inv})
        running_launch.sendStable(500e18, {"from": inv})
    brownie.chain.sleep(delta)
    assert running_launch.fundsProvidedByAddress(accounts[1]) == 1000e18
    venture_bond_address = running_launch.launchVentureBondAddress(
        {"from": accounts[0]}
    )
    nft = brownie.VentureBond.at(venture_bond_address)
    for inv in investors:
        running_launch.claim({"from": inv})
    for n, inv in enumerate(investors):

        assert nft.ownerOf(n) == inv
        assert nft.tokenURI(n, {"from": inv}) == constants.BATCH_SPECIAL_NFT_DATA[n][0]
        assert (
            nft.tokenMetadataHashes(n, {"from": inv})
            == "0x" + constants.BATCH_SPECIAL_NFT_DATA[n][1]
        )


def test_receive_stable_during_offering(
    running_launch, send_1000_stable_to_accounts, accounts
):
    stable_contract = send_1000_stable_to_accounts

    start_time = running_launch.launchStartTime({"from": accounts[1]})
    end_time = running_launch.launchEndTime({"from": accounts[1]})

    start_delta = start_time - time.time() + 1
    brownie.chain.sleep(start_delta)
    running_launch.batchAddToWhitelist([accounts[1], accounts[2], accounts[3]], {"from": accounts[0]})
    number_of_investors = 3
    delta = int((end_time - start_time) / number_of_investors)

    for i in range(number_of_investors):
        stable_contract.increaseAllowance(
            running_launch, 1000e18, {"from": accounts[i + 1]}
        )
        tx = running_launch.sendStable(1000e18, {"from": accounts[i + 1]})

        assert "SupporterFundsDeposited" in tx.events

        brownie.chain.sleep(delta)
        assert running_launch.fundsProvidedByAddress(accounts[i + 1]) == 1000e18

    assert running_launch.totalFundsProvided() == 1000e18 * number_of_investors


def test_receive_eth_reverts_in_launch(running_launch, accounts):
    with brownie.reverts():
        accounts[1].transfer(running_launch, 1 * constants.ETHER)


def test_receive_eth_reverts_in_factory(deployed_factory, accounts):
    with brownie.reverts():
        accounts[1].transfer(deployed_factory, 1 * constants.ETHER)


def test_dev_can_tap_after_successful_launch(successful_launch, accounts):
    launch_contract, stable_contract = successful_launch
    initial_balance = stable_contract.balanceOf(accounts[0], {"from": accounts[0]})

    launch_contract.launcherTap({"from": accounts[0]})
    new_balance = stable_contract.balanceOf(accounts[0], {"from": accounts[0]})

    assert new_balance > initial_balance


def test_dev_cannot_tap_after_failed_launch(failed_launch, accounts):
    with brownie.reverts(
        "The minimum amount was not raised or the launch has not finished"
    ):
        failed_launch.launcherTap({"from": accounts[0]})


def test_cannot_send_stable_after_launch(successful_launch, accounts):
    launch_contract, stable_contract = successful_launch
    with brownie.reverts("Launch has ended"):
        stable_contract.increaseAllowance(launch_contract, 1000, {"from": accounts[1]})
        launch_contract.sendStable(1000, {"from": accounts[1]})


def test_investors_can_claim_after_unsuccessful_launch(
    running_launch, accounts, send_1000_stable_to_accounts
):
    investors = accounts[1:10]
    launch_contract = running_launch
    start_delta = constants.START_DATE - time.time()
    launch_contract.batchAddToWhitelist(investors, {"from": accounts[0]})
    # Sleep until it finishes
    brownie.chain.sleep(int(start_delta) + 1)
    for account in investors:
        send_1000_stable_to_accounts.increaseAllowance(
            running_launch, constants.LOW_INPUT_AMOUNT, {"from": account}
        )
        running_launch.sendStable(constants.LOW_INPUT_AMOUNT, {"from": account})

    brownie.chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)
    for inv in investors:
        launch_contract.claim({"from": inv})
        balance = send_1000_stable_to_accounts.balanceOf(inv)
        assert balance == 1000e18


def test_nft_not_minted_on_failed_launch(
    running_launch, accounts, send_1000_stable_to_accounts
):
    investors = accounts[1:10]
    launch_contract = running_launch
    start_delta = constants.START_DATE - time.time()
    launch_contract.batchAddToWhitelist(investors, {"from": accounts[0]})
    # Sleep until it finishes
    brownie.chain.sleep(int(start_delta) + 1)
    for account in investors:
        send_1000_stable_to_accounts.increaseAllowance(
            running_launch, constants.LOW_INPUT_AMOUNT, {"from": account}
        )
        running_launch.sendStable(constants.LOW_INPUT_AMOUNT, {"from": account})
    venture_bond_address = launch_contract.launchVentureBondAddress(
        {"from": accounts[0]}
    )
    venture_bond_contract = brownie.VentureBond.at(venture_bond_address)
    brownie.chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)
    for inv in investors:
        launch_contract.claim({"from": inv})
        owner = venture_bond_contract.balanceOf(inv, {"from": inv})
        assert owner == 0


def test_investors_claim_nft_after_successful_launch(
    successful_launch, accounts, deployed_factory
):
    investors = accounts[1:10]
    launch_contract, stable_contract = successful_launch
    venture_bond_address = launch_contract.launchVentureBondAddress(
        {"from": accounts[0]}
    )
    venture_bond_contract = brownie.VentureBond.at(venture_bond_address)
    for n, inv in enumerate(investors):
        tx = launch_contract.claim({"from": inv})
        assert "TokenMinted" in tx.events
        token_id = tx.events["TokenMinted"]["tokenId"]
        assert token_id == n
        assert venture_bond_contract.balanceOf(inv, {"from": inv}) == 1
        assert venture_bond_contract.ownerOf(token_id, {"from": inv}) == inv
        assert venture_bond_contract.tokenCreators(
            token_id, {"from": inv}
        ) == deployed_factory.polylaunchSystemAddress({"from": accounts[0]})
        assert venture_bond_contract.previousTokenOwners(
            token_id, {"from": inv}
        ) == deployed_factory.polylaunchSystemAddress({"from": accounts[0]})
        assert (
            venture_bond_contract.lastWithdrawnTime(token_id, {"from": inv})
            == constants.END_DATE
        )
        assert (
            round(
                venture_bond_contract.tapRate(token_id, {"from": inv})
                - int(
                    ((constants.INVESTMENT_AMOUNT * constants.FIXED_SWAP_RATE) / 1e18)
                    / constants.INITIAL_INV_VESTING
                ),
                -2,
            )
            == 0
        )
        assert (
            venture_bond_contract.tappableBalance(token_id, {"from": inv})
            == (constants.INVESTMENT_AMOUNT * constants.FIXED_SWAP_RATE) / 1e18
        )
        assert (
            venture_bond_contract.votingPower(token_id, {"from": inv})
            == (constants.INVESTMENT_AMOUNT * constants.FIXED_SWAP_RATE) / 1e18
        )


def test_fake_investor_fails_claims_nft_after_successful_launch(
    successful_launch, accounts
):
    launch_contract, stable_contract = successful_launch
    with brownie.reverts("msg.sender not eligible"):
        launch_contract.claim({"from": accounts[0]})


def test_investors_tap_nft_after_claiming(successful_launch, accounts):
    tx = []
    investors = accounts[1:10]
    launch_contract, stable_contract = successful_launch
    venture_bond_address = launch_contract.launchVentureBondAddress(
        {"from": accounts[0]}
    )
    venture_bond_contract = brownie.VentureBond.at(venture_bond_address)
    token_for_launch = launch_contract.tokenForLaunch({"from": accounts[1]})
    token_contract = brownie.GovernableERC20.at(token_for_launch)

    for inv in investors:
        tx.append(launch_contract.claim({"from": inv}))

    brownie.chain.sleep(100)
    for n, inv in enumerate(investors):
        for trans in tx:
            if trans.events["TokenMinted"]["owner"] == inv:
                token_id = trans.events["TokenMinted"]["tokenId"]

        old_tappable_balance = venture_bond_contract.tappableBalance(
            token_id, {"from": inv}
        )
        old_withdrawn = venture_bond_contract.lastWithdrawnTime(token_id, {"from": inv})
        assert venture_bond_contract.ownerOf(token_id) == inv
        tx_tap = launch_contract.supporterTap(token_id, {"from": inv})

        assert "SupporterFundsTapped" in tx_tap.events

        new_tappable_balance = venture_bond_contract.tappableBalance(
            token_id, {"from": inv}
        )
        token_amount = tx_tap.events["SupporterFundsTapped"]["amount"]
        new_withdrawn = venture_bond_contract.lastWithdrawnTime(token_id, {"from": inv})

        assert token_contract.balanceOf(inv) == token_amount
        assert new_tappable_balance == old_tappable_balance - token_amount
        assert new_withdrawn > old_withdrawn


def test_investors_tap_nft_after_long_time(successful_launch, accounts):
    tx = []
    investors = accounts[1:10]
    launch_contract, stable_contract = successful_launch
    venture_bond_address = launch_contract.launchVentureBondAddress(
        {"from": accounts[0]}
    )
    venture_bond_contract = brownie.VentureBond.at(venture_bond_address)
    token_for_launch = launch_contract.tokenForLaunch({"from": accounts[1]})
    token_contract = brownie.GovernableERC20.at(token_for_launch)
    brownie.chain.sleep(100000000)
    for inv in investors:
        tx.append(launch_contract.claim({"from": inv}))

    brownie.chain.sleep(100000000)
    for n, inv in enumerate(investors):
        for trans in tx:
            if trans.events["TokenMinted"]["owner"] == inv:
                token_id = trans.events["TokenMinted"]["tokenId"]

        old_tappable_balance = venture_bond_contract.tappableBalance(
            token_id, {"from": inv}
        )
        old_withdrawn = venture_bond_contract.lastWithdrawnTime(token_id, {"from": inv})
        assert venture_bond_contract.ownerOf(token_id) == inv
        tx_tap = launch_contract.supporterTap(token_id, {"from": inv})

        assert "SupporterFundsTapped" in tx_tap.events
        new_tappable_balance = venture_bond_contract.tappableBalance(
            token_id, {"from": inv}
        )
        token_amount = tx_tap.events["SupporterFundsTapped"]["amount"]
        new_withdrawn = venture_bond_contract.lastWithdrawnTime(token_id, {"from": inv})
        assert token_contract.balanceOf(inv) == token_amount
        assert new_tappable_balance == old_tappable_balance - token_amount
        assert new_withdrawn > old_withdrawn


# test sets up such that there are no left over tokens, if you wish to change this, this test may fail
def test_launcher_withdraw_unsold_tokens_fails(successful_launch, accounts):
    launch_contract, _ = successful_launch
    with brownie.reverts("All tokens sold"):
        tx = launch_contract.withdrawUnsoldTokens({"from": accounts[0]})


# this test scenario will use the same parameters but will have one less investor meaning there are left over tokens to withdraw
def test_launcher_withdraw_unsold_tokens_succeeds(
    running_launch, accounts, send_1000_stable_to_accounts
):
    tx = []
    investors = accounts[1:9]
    running_launch.batchAddToWhitelist(investors, {"from": accounts[0]})
    # wait for it to start
    start_delta = constants.START_DATE - time.time()
    brownie.chain.sleep(int(start_delta) + 1)
    
    for n, account in enumerate(investors):
        send_1000_stable_to_accounts.increaseAllowance(
            running_launch, 1000e18 + n * 100e18, {"from": account}
        )
        running_launch.sendStable(100e18 + n * 100e18, {"from": account})

    brownie.chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)

    launch_contract = running_launch
    stable_contract = send_1000_stable_to_accounts
    venture_bond_address = launch_contract.launchVentureBondAddress(
        {"from": accounts[0]}
    )
    venture_bond_contract = brownie.VentureBond.at(venture_bond_address)
    token_for_launch = launch_contract.tokenForLaunch({"from": accounts[1]})
    token_contract = brownie.GovernableERC20.at(token_for_launch)
    brownie.chain.sleep(100000000)
    withdraw = launch_contract.withdrawUnsoldTokens({"from": accounts[0]})
    unsoldTokens = withdraw.events["UnsoldTokensWithdrawn"]["amount"]
    # assert unsoldTokens == (1000e18*constants.FIXED_SWAP_RATE)/1e18
    for inv in investors:
        tx.append(launch_contract.claim({"from": inv}))
    brownie.chain.sleep(100000000)

    for n, inv in enumerate(investors):
        for trans in tx:
            if trans.events["TokenMinted"]["owner"] == inv:
                token_id = trans.events["TokenMinted"]["tokenId"]

        old_tappable_balance = venture_bond_contract.tappableBalance(
            token_id, {"from": inv}
        )
        old_withdrawn = venture_bond_contract.lastWithdrawnTime(token_id, {"from": inv})
        assert venture_bond_contract.ownerOf(token_id) == inv
        tx_tap = launch_contract.supporterTap(token_id, {"from": inv})

        assert "SupporterFundsTapped" in tx_tap.events
        new_tappable_balance = venture_bond_contract.tappableBalance(
            token_id, {"from": inv}
        )
        token_amount = tx_tap.events["SupporterFundsTapped"]["amount"]
        new_withdrawn = venture_bond_contract.lastWithdrawnTime(token_id, {"from": inv})
        assert token_contract.balanceOf(inv) == token_amount
        assert new_tappable_balance == old_tappable_balance - token_amount
        assert new_withdrawn > old_withdrawn


def test_investors_tap_nft_after_failed_launch(
    running_launch, accounts, send_1000_stable_to_accounts
):
    investors = accounts[1:10]
    launch_contract = running_launch
    start_delta = constants.START_DATE - time.time()
    launch_contract.batchAddToWhitelist(investors, {"from": accounts[0]})
    brownie.chain.sleep(int(start_delta) + 1)
    for account in investors:
        send_1000_stable_to_accounts.increaseAllowance(
            running_launch, constants.LOW_INPUT_AMOUNT, {"from": account}
        )
        running_launch.sendStable(constants.LOW_INPUT_AMOUNT, {"from": account})
    brownie.chain.sleep(int(constants.END_DATE - constants.START_DATE) + 1)

    with brownie.reverts("Launch Unsuccessful."):
        launch_contract.supporterTap(0, {"from": accounts[1]})


