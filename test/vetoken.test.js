const { BN, expectRevert, time } = require('@openzeppelin/test-helpers');
const { expect, assert } = require('chai');

const veSEVN = artifacts.require('/artifacts/VeSevn');
const BigNumber = require("bignumber.js");
const web3 = require('web3');

contract('veSevn', ([owner, deployer]) => {

    beforeEach(async function () {
        this.instanse = await veSEVN.new({ from: deployer })
    })

    it('should set correct values', async function (){
        expect(await this.instanse.name.call(), 'VeSevn')
        expect(await this.instanse.symbol.call(), 'veSEVN')
        expect(await this.instanse.owner.call(), deployer)
    })

    it('setup owner', async function(){
        await expect(this.instanse.transferOwnership(owner, {from: owner})).to.be.revertedWith('Ownable: caller is not the owner')
        await this.instanse.transferOwnership(owner, {from: deployer})
        await expect(this.instanse.renounceOwnership({from: owner})).to.be.revertedWith('VeSevnToken: Cannot renounce, can only transfer ownership')
    
        await expect(this.instanse.setBoostedMasterChefSevn('0x0000000000000000000000000000000000000000', {from: deployer})).to.be.revertedWith('Ownable: caller is not the owner')
        await this.instanse.setBoostedMasterChefSevn('0x0000000000000000000000000000000000000000', {from: owner})
    })

    it('mint', async function(){
        await this.instanse.transferOwnership(owner, {from: deployer})
        await expect(this.instanse.mint(owner, web3.utils.toWei("50",'ether'), {from: deployer})).to.be.revertedWith('Ownable: caller is not the owner')
        await this.instanse.mint(owner, web3.utils.toWei('50','ether'), {from: owner})
        expect(new BigNumber(await this.instanse.balanceOf(owner)).toFixed(), web3.utils.toWei("50", 'ether'))
    })

    it('burn', async function(){
        await this.instanse.mint(owner, web3.utils.toWei('50','ether'), {from: deployer})
        expect(new BigNumber(await this.instanse.balanceOf(owner)).toFixed(), web3.utils.toWei("50", 'ether'))
        await expect(this.instanse.burnFrom(owner, web3.utils.toWei("50",'ether'), {from: owner})).to.be.revertedWith('Ownable: caller is not the owner')
        await this.instanse.burnFrom(owner, web3.utils.toWei("50",'ether'), {from: deployer});
        expect(new BigNumber(await this.instanse.balanceOf(owner)).toFixed(), web3.utils.toWei("0", 'ether'))
    })

    

})