## Ropsten

Deployed at address [`0x607B2A8B582e66006CC53c8326f8DF55431172ea`](https://ropsten.etherscan.io/address/0x607B2A8B582e66006CC53c8326f8DF55431172ea) with token address [`0x5861B3DC52339d4f976B7fa5d80dB6cd6f477F1B`](https://ropsten.etherscan.io/token/0x5861b3dc52339d4f976b7fa5d80db6cd6f477f1b).

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