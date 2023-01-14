import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  gasReporter: {
    enabled: true,
    coinmarketcap: "f34c1bdd-9b6b-427a-ada4-09517ba1e365",
    token: "ETH",
    gasPriceApi: "https://api.bscscan.com/api?module=proxy&action=eth_gasPrice"
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true
    },
    bsc_testnet: {
        url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
        chainId: 97,
        accounts: process.env.DEPLOYER_PRIVATE_KEY
            ? [process.env.DEPLOYER_PRIVATE_KEY as string]
            : undefined,
    },
    bsc_mainnet: {
        url: "https://bsc-dataseed.binance.org/",
        chainId: 56,
        accounts: process.env.DEPLOYER_PRIVATE_KEY
            ? [process.env.DEPLOYER_PRIVATE_KEY as string]
            : undefined,
    },
    arbitrum: {
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
      accounts: process.env.DEPLOYER_PRIVATE_KEY
          ? [process.env.DEPLOYER_PRIVATE_KEY as string]
          : undefined,
    },
    fantom: {
      url: "https://rpcapi.fantom.network/",
      chainId: 250,
      accounts: process.env.DEPLOYER_PRIVATE_KEY
          ? [process.env.DEPLOYER_PRIVATE_KEY as string]
          : undefined,
    }
  },
  etherscan: {
      apiKey: {
          bscTestnet: '4SM3MYR8D3PIFFA1I913FIUPK83S3BT7UJ',
          bsc: '4SM3MYR8D3PIFFA1I913FIUPK83S3BT7UJ'
      }
  },
  paths: {
      sources: 'contracts'
  },
  typechain: {
    externalArtifacts: ['abis/*.json']
  },
};

export default config;
