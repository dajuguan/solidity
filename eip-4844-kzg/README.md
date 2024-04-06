Demo of using [point evaluation precompile](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-4844.md#point-evaluation-precompile) of EIP-4844 to prove blob at specific index 
## kzg-4844 python
Require python=^3.9
```
cd python
pip install ckzg=1.0.0
```
### Ref: 
- [c-kzg-4844](https://github.com/ethereum/c-kzg-4844/blob/main/bindings/python/tests.py)
- [js c-kzg](https://github.com/ethers-io/ethers.js/issues/4650#issuecomment-2021007162)

## Hardhat kzg

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
cd hardhat
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```
