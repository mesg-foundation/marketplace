## Mainnet

Deployed at address [`0x0c6e8d0ec4770fda8a56cd912392d2ff14822952`](https://etherscan.io/address/0x0c6e8d0ec4770fda8a56cd912392d2ff14822952) with token address [`0x420167d87d35c3a249b32ef6225872fbd9ab85d2`](https://etherscan.io/token/0x420167d87d35c3a249b32ef6225872fbd9ab85d2).

## Ropsten

Deployed at address [`0xeCC1A867F871323350A1A89FcAf69629a2d5085e`](https://ropsten.etherscan.io/address/0xeCC1A867F871323350A1A89FcAf69629a2d5085e) with token address [`0x5861B3DC52339d4f976B7fa5d80dB6cd6f477F1B`](https://ropsten.etherscan.io/token/0x5861b3dc52339d4f976b7fa5d80db6cd6f477f1b).

## Installation

- `npm install`

## Test

```
npm run ganache-cli
npm run test
```

## Migrate

```
npm run migrate
```

## Generate Typescript definition

```
npm run typescript
```

## Code coverage

```
npm run coverage
```

## Deploy on Ropsten

```
source .envrc; npm run migrate -- --network=ropsten
```