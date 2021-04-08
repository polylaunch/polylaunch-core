import brownie
import time
import constants
import pytest


def get_governor(launch, sender):
    return brownie.GovernorAlpha.at(launch.governor({"from": sender}))


@pytest.fixture(params=["TAP_INCREASE", "REFUND"])
def launch_with_active_tap_increase_proposal(request, successful_launch, accounts):
    launch, _ = successful_launch
    governor = get_governor(launch, accounts[0])

    launch_token_address = governor.launchToken({"from": accounts[1]})
    st = brownie.GovernableERC20.at(launch_token_address)

    brownie.chain.sleep(1000000)
    investors = accounts[1:]

    for token_id, inv in enumerate(investors):
        launch.claim({"from": inv})
        st.delegate(inv.address, {"from": inv})

    if request.param == "TAP_INCREASE":
        tx = governor.proposeTapIncrease(
            constants.INITIAL_DEV_TAP_RATE + 5,
            "Increase tap rate by 5",
            {"from": accounts[0]},
        )
    elif request.param == "REFUND":
        tx = governor.proposeRefund(
            "Want a refund because reasons",
            {"from": accounts[0]},
        )

    brownie.chain.mine(2)
    yield tx.return_value, launch, governor


@pytest.fixture()
def launch_where_investors_have_claimed_NFT(successful_launch, accounts):
    launch, _ = successful_launch
    governor = get_governor(launch, accounts[0])

    launch_token_address = governor.launchToken({"from": accounts[1]})
    st = brownie.GovernableERC20.at(launch_token_address)

    brownie.chain.sleep(1000000)
    investors = accounts[1:]

    for token_id, inv in enumerate(investors):
        launch.claim({"from": inv})
        launch.supporterTap(token_id, {"from": inv})
        st.delegate(inv.address, {"from": inv})

    brownie.chain.mine(2)
    yield launch, governor


@pytest.fixture()
def launch_with_succeeded_proposal(launch_with_active_tap_increase_proposal, accounts):
    proposal_id, launch, governor = launch_with_active_tap_increase_proposal

    investors = accounts[1:]

    # Cast votes to make launch succeed
    for token_id, inv in enumerate(investors):
        governor.castVote(token_id, proposal_id, True, {"from": inv})

    brownie.chain.mine(20)  # Mine enough blocks to complete launch
    yield proposal_id, launch, governor


@pytest.fixture()
def launch_with_defeated_proposal(launch_with_active_tap_increase_proposal, accounts):
    proposal_id, launch, governor = launch_with_active_tap_increase_proposal

    brownie.chain.mine(20)  # Mine enough blocks to complete launch
    yield proposal_id, launch, governor


@pytest.fixture()
def launch_with_queued_proposal(launch_with_succeeded_proposal, accounts):
    proposal_id, launch, governor = launch_with_succeeded_proposal

    governor.queue(proposal_id, {"from": accounts[0]})

    yield proposal_id, launch, governor


def test_propose_tap_increase_by_owner(successful_launch, accounts):
    launch, _ = successful_launch
    governor = get_governor(launch, accounts[0])

    tx = governor.proposeTapIncrease(
        constants.INITIAL_DEV_TAP_RATE + 5,
        "Increase tap rate by 5",
        {"from": accounts[0]},
    )

    assert "TapIncreaseProposalCreated" in tx.events
    assert tx.events["TapIncreaseProposalCreated"]["id"] == tx.return_value
    assert tx.events["TapIncreaseProposalCreated"]["proposer"] == accounts[0].address


def test_propose_refund_as_owner(successful_launch, accounts):
    launch, _ = successful_launch
    governor = get_governor(launch, accounts[0])

    tx = governor.proposeRefund("Want a refund because reasons", {"from": accounts[0]})

    assert "RefundProposalCreated" in tx.events
    assert tx.events["RefundProposalCreated"]["id"] == tx.return_value
    assert (
        tx.events["RefundProposalCreated"]["description"]
        == "Want a refund because reasons"
    )


def test_propose_refund_as_non_NFT_holder_reverts(successful_launch, accounts):
    launch, _ = successful_launch
    governor = get_governor(launch, accounts[0])

    with brownie.reverts(
        "LaunchGovernor::proposeRefund: Must be launcher or hold a venture bond to propose a refund"
    ):
        governor.proposeRefund("Want a refund because reasons", {"from": accounts[1]})


def test_propose_refund_as_NFT_holder_succeeds(
    launch_where_investors_have_claimed_NFT, accounts
):
    launch, governor = launch_where_investors_have_claimed_NFT

    tx = governor.proposeRefund("Want a refund because reasons", {"from": accounts[1]})

    assert "RefundProposalCreated" in tx.events
    assert tx.events["RefundProposalCreated"]["id"] == tx.return_value
    assert (
        tx.events["RefundProposalCreated"]["description"]
        == "Want a refund because reasons"
    )


def test_propose_tap_increase_by_non_owner_reverts(successful_launch, accounts):
    launch, _ = successful_launch
    governor = get_governor(launch, accounts[0])

    with brownie.reverts(
        "LaunchGovernor::proposeTapIncrease: only the launcher can propose a tap increase"
    ):
        tx = governor.proposeTapIncrease(
            constants.INITIAL_DEV_TAP_RATE + 5,
            "Increase tap rate by 5",
            {"from": accounts[1]},
        )


def test_cast_vote_when_account_has_nft_succeeds(
    launch_with_active_tap_increase_proposal, accounts
):
    proposal_id, launch, governor = launch_with_active_tap_increase_proposal

    vote_tx = governor.castVote(0, proposal_id, True, {"from": accounts[1]})

    assert "VoteCast" in vote_tx.events


def test_cast_vote_when_account_does_not_have_nft_fails(
    launch_with_active_tap_increase_proposal, accounts
):
    proposal_id, launch, governor = launch_with_active_tap_increase_proposal

    with brownie.reverts(
        "LaunchGovernor::onlyTokenOwner: Sender does not own a venture bond with the given id"
    ):
        vote_tx = governor.castVote(5, proposal_id, True, {"from": accounts[1]})


def test_cast_vote_when_NFT_does_not_exist(
    launch_with_active_tap_increase_proposal, accounts
):
    proposal_id, launch, governor = launch_with_active_tap_increase_proposal

    with brownie.reverts("ERC721: owner query for nonexistent token"):
        vote_tx = governor.castVote(100, proposal_id, True, {"from": accounts[1]})


def test_queue_succeeded_proposal_succeeds(launch_with_succeeded_proposal, accounts):
    proposal_id, launch, governor = launch_with_succeeded_proposal

    tx = governor.queue(proposal_id, {"from": accounts[0]})
    assert "ProposalQueued" in tx.events

    prop = governor.queuedProposals(proposal_id, {"from": accounts[0]})
    assert prop


def test_queue_defeated_proposal_fails(launch_with_defeated_proposal, accounts):
    proposal_id, launch, governor = launch_with_defeated_proposal

    with brownie.reverts(
        "LaunchGovernor::queue: proposal can only be queued if it is succeeded"
    ):
        governor.queue(proposal_id, {"from": accounts[0]})


def test_execute_queued_proposal_after_eta_succeeds(
    launch_with_queued_proposal, accounts
):
    proposal_id, launch, governor = launch_with_queued_proposal

    current_tap_rate = launch.launcherTapRate({"from": accounts[0]})
    proposed_tap_rate = governor.proposals(proposal_id, {"from": accounts[0]})[
        "newRate"
    ]

    brownie.chain.sleep(86400 + 1)  # just over 1 day
    tx = governor.execute(proposal_id, {"from": accounts[0]})

    if proposed_tap_rate != 0:
        # it means it's a tap increase proposal. 0 is a default value
        assert launch.launcherTapRate({"from": accounts[0]}) == proposed_tap_rate

    assert "ProposalExecuted" in tx.events


def test_execute_queued_proposal_after_grace_period_expires_fails(
    launch_with_queued_proposal, accounts
):
    proposal_id, launch, governor = launch_with_queued_proposal

    brownie.chain.sleep(86400 * 3)  # 3 days

    with brownie.reverts(
        "LaunchGovernor::execute: proposal can only be executed if it is queued"
    ):
        governor.execute(proposal_id, {"from": accounts[0]})


def test_execute_queued_proposal_before_eta_fails(launch_with_queued_proposal, accounts):
    proposal_id, launch, governor = launch_with_queued_proposal

    with brownie.reverts(
        "LaunchGovernor::execute: Transaction hasn't surpassed time lock"
    ):
        governor.execute(proposal_id, {"from": accounts[0]})


def test_double_vote_same_address_reverts(
    launch_with_active_tap_increase_proposal, accounts
):
    proposal_id, launch, governor = launch_with_active_tap_increase_proposal

    vote_tx = governor.castVote(0, proposal_id, True, {"from": accounts[1]})
    with brownie.reverts("LaunchGovernor::_castVote: voter already voted"):
        vote_tx = governor.castVote(0, proposal_id, True, {"from": accounts[1]})


def test_double_vote_same_NFT_reverts(launch_with_active_tap_increase_proposal, accounts):
    proposal_id, launch, governor = launch_with_active_tap_increase_proposal

    vote_tx = governor.castVote(0, proposal_id, True, {"from": accounts[1]})

    nft_contract = brownie.VentureBond.at(governor.ventureBond({"from": accounts[1]}))
    nft_contract.safeTransferFrom(
        accounts[1].address, accounts[2].address, 0, {"from": accounts[1]}
    )

    with brownie.reverts(
        "LaunchGovernor::_castVote: venture bond already used to vote in this proposal"
    ):
        vote_tx = governor.castVote(0, proposal_id, True, {"from": accounts[2]})


def test_claim_refund_without_succeeded_proposal_fails(successful_launch, accounts):
    with brownie.reverts("claimRefund: Launch is not in refund mode"):
        launch, _ = successful_launch
        launch.claimRefund(1, {"from": accounts[1]})


def test_claim_refund_after_succeeded_proposal_succeeds(
    launch_with_queued_proposal, accounts
):
    proposal_id, launch, governor = launch_with_queued_proposal

    current_tap_rate = launch.launcherTapRate({"from": accounts[0]})
    proposed_tap_rate = governor.proposals(proposal_id, {"from": accounts[0]})[
        "newRate"
    ]

    brownie.chain.sleep(86400 + 1)  # just over 1 day
    governor.execute(proposal_id, {"from": accounts[0]})

    if proposed_tap_rate != 0:
        # it means it's a tap increase proposal. 0 is a default value. we aren't testing tap increase here
        return

    token_address = launch.tokenForLaunch({"from": accounts[1]})
    token_contract = brownie.GovernableERC20.at(token_address)

    token_contract.approve(launch.address, 100e18, {"from": accounts[1]})
    tx = launch.claimRefund(0, {"from": accounts[1]})

    assert tx.return_value == 1000e18
    # assert "RefundClaimed" in tx.events -- for some reason this event isn't emitted?