import time
import brownie

AMOUNT_FOR_SALE = 9_000_000e18
START_DATE = time.time() + 1200
END_DATE = time.time() + 3600
MINIMUM_FUNDING = 1000e18
INITIAL_DEV_VESTING = 31536000
INITIAL_INV_VESTING = 31536000
FUNDING_CAP = 9000e18
INDIVIDUAL_FUNDING_CAP = 5000e18
FIXED_SWAP_RATE = 1000e18
ETHER = 1e18
NFT_NAME = "DUMMY CONTROL"
DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
CDAI = "0x5d3a536e4d6dbd6114cc1ead35777bab948e3643"
AAVE_LENDING_POOL = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
NFT_SYMBOL = "DUM"
LOW_INPUT_AMOUNT = 10
ASK_PRICE = 200
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
BID_PRICE = 200
stable_AMOUNT = 5000
GENERIC_NFT_DATA = [
    "https://test",
    "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078",
]
SPECIAL_NFT_DATA = [
    "https://test",
    "194F55A6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078",
]
BATCH_SPECIAL_NFT_DATA = [
    [
        "https://test",
        "d9a7e81efacc5660697cf4866d1af38e99275e02b2454b1dccaeb15adf66f575",
    ],
    [
        "https://test",
        "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078",
    ],
    [
        "https://test",
        "f9a7e81efacc5660697cf4866d1af38e99275e02b2454b1dccaeb15adf66f575",
    ],
    [
        "https://test",
        "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078",
    ],
    [
        "https://test",
        "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078",
    ],
]

FAILURE_NFT_DATA = [
    ["", "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078"],
    [
        "https://test",
        "",
    ],
    ["https://test", "0"],
]

DUMMY_IPFS_HASH = "QmSVw4PiXLNarB9jt27qQaT5uhGepnMgsn7Duba6pj7R9k"
