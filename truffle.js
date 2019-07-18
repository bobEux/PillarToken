const HDWalletProvider = require('truffle-hdwallet-provider')
// Allows us to use ES6 in our migrations and tests.
require('babel-register')

const mnemonic = 'false myself sadness rebuild shallow powder outdoor thank basket light fun tip';

module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // Match any network id
      provider: function() {
        return new HDWalletProvider(mnemonic, 'http://localhost:8545/', 0, 10)
      }
    },
    main: {
      gas: 4712388,
      gasPrice: 450000000000,
      host: 'localhost',
      port: 8545,
      network_id: '*' // Match any network id
    },
    rinkeby: {
      gas: 4012388,
      gasPrice: 450000000000,
      host: 'localhost',
      port: 8545,
      network_id: '*' // Match any network id
    },
    kovan: {
      host: 'localhost',
      port: 8545,
      network_id: '*' // Match any network id
    },
    ropsten: {
      host: 'localhost',
      port: 8545,
      network_id: '*' // Match any network id
    }
  }
}
