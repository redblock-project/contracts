require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");

const dotenv = require("dotenv");
dotenv.config();

module.exports = {
  networks: {
    hardhat: {
      initialDate: "1970-01-01T00:00:00Z",
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      initialDate: "1970-01-01T00:00:00Z",
      gasMultiplier: 1.1,
      gas: "auto",
      gasPrice: 100 * 10 ** 9,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
      gasMultiplier: 1.1,
      gas: "auto",
      gasPrice: 2 * 10 ** 9,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
      gasMultiplier: 1.1,
      gas: "auto",
      gasPrice: 110 * 10 ** 9,
    },
  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  etherscan: {
    apiKey: `${process.env.ETHERSCAN_KEY}`,
  },
  mocha: {
    timeout: 1000000,
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 100,
    enabled: true,
    coinmarketcap: `${process.env.COINMARKETCAP_KEY}`,
  },
};
