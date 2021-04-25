# Polylaunch Protocol

This repo uses brownie, to run the tests carry out all the necessary brownie setup.

To run the standard tests:

```
$ cd solidity
$ brownie test tests/standard-tests
```
 To run the mainnet tests:
 
Set up an infura id in your environmental variables.

For it to work fast you need your ETHERSCAN_TOKEN api key in your environmental variables

https://eth-brownie.readthedocs.io/en/stable/network-management.html#using-infura 
```
$ cd solidity
$ brownie test tests/mainnet-fork-tests --network mainnet-fork
```

## Polylaunch Protocol Flowcharts

Overall Polylaunch Protocol - 5th April 2021


![Main Contract Flow](./docs/contract-flowcharts/main.png)

Figure A - Prelaunch interactions - 5th April 2021


![Figure A](./docs/contract-flowcharts/figure-a-prelaunch.png)

Figure B - Venture Bond and Market interactions - 5th April 2021


![Figure B](./docs/contract-flowcharts/figure-b-venture-bond-interactions.png)

Figure C - Polylaunch Governance - 5th April 2021


![Figure C](./docs/contract-flowcharts/figure-c-governance.png)

## Gas Profile
```
BasicERC20 <Contract>
   ├─ constructor             -  avg:  741304  avg (confirmed):  741304  low:  741304  high:  741304
   ├─ mint                    -  avg:   51185  avg (confirmed):   51185  low:   35413  high:   65413
   └─ increaseAllowance       -  avg:   45223  avg (confirmed):   45223  low:   30266  high:   45278
BasicLaunch <Contract>
   ├─ constructor             -  avg: 5074884  avg (confirmed): 5074884  low: 5074884  high: 5074884
   ├─ claim                   -  avg:  386109  avg (confirmed):  386774  low:   31696  high:  429275
   ├─ batchSetNftDataByIndex  -  avg:  184146  avg (confirmed):  261124  low:   30193  high:  261124
   ├─ supporterTap            -  avg:  118839  avg (confirmed):  125259  low:   34977  high:  132970
   ├─ sendUSD                 -  avg:   82764  avg (confirmed):   82862  low:   24115  high:  134642
   ├─ claimRefund             -  avg:   70250  avg (confirmed):  117179  low:   23322  high:  117179
   ├─ launcherTap             -  avg:   48827  avg (confirmed):   70365  low:   27289  high:   70365
   ├─ withdrawUnsoldTokens    -  avg:   47861  avg (confirmed):   69035  low:   26688  high:   69035
   └─ setNftDataByIndex       -  avg:   36202  avg (confirmed):   70075  low:   24828  high:   70075
GovernableERC20 <Contract>
   ├─ constructor             -  avg: 2276818  avg (confirmed): 2276818  low: 2276818  high: 2276818
   ├─ delegate                -  avg:   47721  avg (confirmed):   47721  low:   45791  high:   91118
   └─ approve                 -  avg:   45223  avg (confirmed):   45223  low:   45212  high:   45224
GovernorAlpha <Contract>
   ├─ constructor             -  avg: 2072820  avg (confirmed): 2072820  low: 2072820  high: 2072820
   ├─ proposeTapIncrease      -  avg:  175088  avg (confirmed):  187335  low:   28153  high:  187335
   ├─ proposeRefund           -  avg:  160632  avg (confirmed):  170367  low:   34085  high:  170456
   ├─ castVote                -  avg:  135612  avg (confirmed):  144116  low:   26949  high:  144843
   ├─ queue                   -  avg:   72718  avg (confirmed):   80490  low:   33869  high:   80490
   └─ execute                 -  avg:   65550  avg (confirmed):   92231  low:   38441  high:  113838
LaunchFactory <Contract>
   └─ createBasicLaunch       -  avg:  735580  avg (confirmed):  762177  low:   26381  high:  766342
LaunchGovernance <Contract>
   └─ constructor             -  avg:  636808  avg (confirmed):  636808  low:  636808  high:  636808
LaunchLogger <Contract>
   └─ constructor             -  avg:  426774  avg (confirmed):  426774  low:  426774  high:  426774
LaunchRedemption <Contract>
   └─ constructor             -  avg:   71933  avg (confirmed):   71933  low:   71933  high:   71933
LaunchUtils <Contract>
   └─ constructor             -  avg:   71933  avg (confirmed):   71933  low:   71933  high:   71933
Market <Contract>
   ├─ setBid                  -  avg:   24966  avg (confirmed):       0  low:   24966  high:   24966
   ├─ setBidShares            -  avg:   23678  avg (confirmed):       0  low:   23678  high:   23678
   ├─ setAsk                  -  avg:   23297  avg (confirmed):       0  low:   23297  high:   23297
   └─ configure               -  avg:   22791  avg (confirmed):       0  low:   22791  high:   22791
PolylaunchConstants <Contract>
   └─ constructor             -  avg:  135863  avg (confirmed):  135863  low:  135863  high:  135863
PolylaunchSystem <Contract>
   └─ constructor             -  avg: 7984254  avg (confirmed): 7984254  low: 7984254  high: 7984254
PolylaunchSystemAuthority <Contract>
   └─ constructor             -  avg:  107760  avg (confirmed):  107760  low:  107760  high:  107760
VentureBond <Contract>
   ├─ setBid                  -  avg:  146905  avg (confirmed):  163350  low:   50106  high:  242074
   ├─ acceptBid               -  avg:   80989  avg (confirmed):  193754  low:   36466  high:  193754
   ├─ setAsk                  -  avg:   80301  avg (confirmed):   84362  low:   35321  high:   84369
   ├─ safeTransferFrom        -  avg:   71265  avg (confirmed):   71265  low:   71265  high:   71265
   ├─ transferFrom            -  avg:   54368  avg (confirmed):   54368  low:   54368  high:   54368
   ├─ removeBid               -  avg:   35577  avg (confirmed):   40907  low:   28395  high:   40907
   ├─ mint                    -  avg:   30916  avg (confirmed):       0  low:   30916  high:   30916
   ├─ updateTapRate           -  avg:   27278  avg (confirmed):       0  low:   27271  high:   27283
   ├─ updateLastWithdrawnTime -  avg:   27211  avg (confirmed):       0  low:   27204  high:   27216
   ├─ updateTappableBalance   -  avg:   27189  avg (confirmed):       0  low:   27182  high:   27194
   ├─ updateVotingPower       -  avg:   27158  avg (confirmed):       0  low:   27151  high:   27163
   └─ removeAsk               -  avg:   25985  avg (confirmed):   25036  low:   25032  high:   34534
VentureBondDataRegistry <Contract>
   └─ constructor             -  avg:  163787  avg (confirmed):  163787  low:  163787  high:  163787
```
