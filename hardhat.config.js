require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");

const { mnemonic, EtherscanAPIKey, PRIVKEY, AlchemyProjID } = require("./secrets.json");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
    const accounts = await ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    networks: {
        hardhat: {
            forking: {
                url: `https://eth-mainnet.alchemyapi.io/v2/${AlchemyProjID}`,
                accounts: [`0x${PRIVKEY}`],
            }
        },
        bsctestnet: {
            url: `https://data-seed-prebsc-1-s1.binance.org:8545/`,
            accounts: {
                mnemonic: mnemonic
            }
        },
        bscmainnet: {
            url: `https://bsc-dataseed3.ninicoin.io/`,
            accounts: {
                mnemonic: mnemonic
            },
            gasPrice: 10 * 1e9
        },
        mainnet: {
            url: `https://eth-mainnet.alchemyapi.io/v2/${AlchemyProjID}`,
            accounts: [`0x${PRIVKEY}`],
            gasPrice: 42 * 1e9
        }
    },
    solidity: {
        version: "0.7.3",
        settings: {
            optimizer: {
                enabled: true,
                runs: 10
            }
        }
    },
    etherscan: {
        apiKey: EtherscanAPIKey
    },
    namedAccounts: {
        deployer: 0,
        tokenOwner: 1
    },
    mocha: {
        timeout: 20000000
    }
};
