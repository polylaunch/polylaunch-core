import time
import brownie

AMOUNT_FOR_SALE = 9000000e18 # should be fixed swap rate * funding cap for tests
START_DATE = time.time() + 1200
END_DATE = time.time() + 3600
MINIMUM_FUNDING = 1000e18
INITIAL_DEV_TAP_RATE = 5e15
INITIAL_INV_TAP_RATE = 5e15
FUNDING_CAP = 9000e18
INDIVIDUAL_FUNDING_CAP = 5000e18
FIXED_SWAP_RATE = 1000e18
INVESTMENT_AMOUNT = 1000e18
ETHER = 1e18
NFT_NAME = "DUMMY CONTROL"
NFT_SYMBOL = "DUM"
LOW_INPUT_AMOUNT = 10e18
ASK_PRICE = 200e18
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
BID_PRICE = 200e18
USD_AMOUNT = 5000e18
GENERIC_NFT_DATA = ["https://test",
                    "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078"
                    ]
SPECIAL_NFT_DATA = ["https://test",
                    "194F55A6FA5CD48B9DD2CACDD9698792602A4EDCB72B9B7CB410124CCFD79078"
                    ]
BATCH_SPECIAL_NFT_DATA = [
    ["https://test",
     "d9a7e81efacc5660697cf4866d1af38e99275e02b2454b1dccaeb15adf66f575"
     ],
    ["https://test",
     "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078"
     ],
    ["https://test",
     "f9a7e81efacc5660697cf4866d1af38e99275e02b2454b1dccaeb15adf66f575"
     ],
    ["https://test",
     "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078"
     ],
    ["https://test",
     "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078"
     ]
]

FAILURE_NFT_DATA = [
    ["",
     "194F55B6FA5CD48B9DD2CACDD9598792602A4EDCB72B9B7CB410124CCFD79078"
     ],
    ["https://test",
     "",
     ],
    ["https://test",
     "0"
     ]
]
