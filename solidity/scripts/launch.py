#!/usr/bin/python3

from brownie import (
    accounts,
    LaunchFactory,
    BasicLaunch,
    LaunchUtils,
    PolylaunchSystem,
    PolylaunchSystemAuthority,
    PolylaunchConstants,
    BasicERC20,
)


# change to accounts[0] for local network
def main():
    contract = BasicERC20.deploy("Dai Stablecoin", "DAI", {"from": accounts[0]})
    constants = PolylaunchConstants.deploy({"from": accounts[0]})
    utils = LaunchUtils.deploy({"from": accounts[0]})
    system = PolylaunchSystem.deploy(contract.address, {"from": accounts[0]})
    auth = PolylaunchSystemAuthority.deploy(system.address, {"from": accounts[0]})
    factory = LaunchFactory.at(
        system.tx.events["PolylaunchSystemLaunched"]["factoryAddress"]
    )
