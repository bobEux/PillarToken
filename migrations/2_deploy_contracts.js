var SafeMath = artifacts.require('./zeppelin/SafeMath.sol');
// var PillarPresale = artifacts.require('./PillarPresale.sol');
var UnsoldAllocation = artifacts.require('./UnsoldAllocation.sol');
var TeamAllocation = artifacts.require("./TeamAllocation.sol");
var PillarToken = artifacts.require("./PillarToken.sol");

module.exports = function(deployer) {
 //mainnet
  const tokenMultisigWallet = '0xF5aFd2285e071e1e8e415Ce9Af8641fdBF66410d';
  const icedWallet = '0xF5aFd2285e071e1e8e415Ce9Af8641fdBF66410d';

  deployer.deploy(SafeMath);
  //deployer.link(SafeMath,PillarPresale);
  //deployer.deploy(PillarPresale,presaleMultisigWallet,presaleStartBlock,presaleEndBlock);
  deployer.link(SafeMath,UnsoldAllocation);
  deployer.link(SafeMath,TeamAllocation);
  deployer.link(SafeMath,PillarToken);
  deployer.deploy(PillarToken,tokenMultisigWallet,icedWallet);
};
