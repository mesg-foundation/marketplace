## Ropsten

Deployed at address [`0x76130BD3a6a1B943C83f3c16c682Bd90a04638f4`](https://ropsten.etherscan.io/address/0x76130BD3a6a1B943C83f3c16c682Bd90a04638f4) with token address [`0x5861B3DC52339d4f976B7fa5d80dB6cd6f477F1B`](https://ropsten.etherscan.io/token/0x5861b3dc52339d4f976b7fa5d80db6cd6f477f1b).

## Installation

- Install [Ganache](https://github.com/trufflesuite/ganache/releases/latest)
- `npm install`

## Test

```
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