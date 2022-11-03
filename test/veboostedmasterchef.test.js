const { BN, expectRevert, time } = require('@openzeppelin/test-helpers');
const { expect, assert, use } = require('chai');

const SEVN = artifacts.require('/artifacts/Sevn');
const ERC20 = artifacts.require('/artifacts/ERC20Mock');
const veSEVN = artifacts.require('/artifacts/VeSevn');
const SevnStaking = artifacts.require('/artifacts/VeSevnStaking');
const MasterChef = artifacts.require('/artifacts/MasterChef');
const BoostedMasterChefSevn = artifacts.require('/artifacts/BoostedMasterChefSevn');

const BigNumber = require("bignumber.js");
const web3 = require('web3');   


contract('BoosteMasterChef', ([deployer, bob, carol, alice,  dev, treasury, safu]) => {

    before(async function(){



    });


});
