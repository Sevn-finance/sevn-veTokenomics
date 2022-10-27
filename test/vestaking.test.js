const { BN, expectRevert, time } = require('@openzeppelin/test-helpers');
const { expect, assert, use } = require('chai');

const SEVN = artifacts.require('/artifacts/Sevn');
const veSEVN = artifacts.require('/artifacts/VeSevn');
const SevnStaking = artifacts.require('/artifacts/VeSevnStaking');

const BigNumber = require("bignumber.js");
const web3 = require('web3');


contract('veSevnStaking', ([deployer, bob, carol, alice]) => {

    before(async function(){
        this.veSevnPerSharePerSec = web3.utils.toWei("1", 'ether');
        this.speedUpVeSevnPerSharePerSec = web3.utils.toWei("1", 'ether');
        this.speedUpThreshold = 5;
        this.speedUpDuration = 50;
        this.maxCapPct = 20000;
    })

    beforeEach(async function(){

        this.sevn = await SEVN.new('Sevn', 'SEVN', {from: deployer})
        this.veSevn = await veSEVN.new({from: deployer})
        this.SevnStaking = await SevnStaking.new(
            this.sevn.address,
            this.veSevn.address,
            this.veSevnPerSharePerSec,
            this.speedUpVeSevnPerSharePerSec,
            this.speedUpThreshold,
            this.speedUpDuration,
            this.maxCapPct,
            {from: deployer}
        )

        await this.veSevn.transferOwnership(this.SevnStaking.address, {from: deployer}) 

        await this.sevn.transfer(bob, web3.utils.toWei('1000', 'ether'),{from: deployer})
        await this.sevn.transfer(carol, web3.utils.toWei('1000', 'ether'),{from: deployer})
        await this.sevn.transfer(alice, web3.utils.toWei('1000', 'ether'),{from: deployer})

        await this.sevn.approve(this.SevnStaking.address, web3.utils.toWei('1000', 'ether'), {from: bob})
        await this.sevn.approve(this.SevnStaking.address, web3.utils.toWei('1000', 'ether'), {from: carol})
        await this.sevn.approve(this.SevnStaking.address, web3.utils.toWei('1000', 'ether'), {from: alice})

    })

    describe('setMaxCapPct', function(){

        it("should not allow non-owner to setMaxCapPct", async function () {
            await expect(
              this.SevnStaking.setMaxCapPct(this.maxCapPct + 1, {from: alice})
            ).to.be.revertedWith("Ownable: caller is not the owner");
          });
      
          it("should not allow owner to set lower maxCapPct", async function () {
            expect(new BigNumber(await this.SevnStaking.maxCapPct()).toFixed()).to.be.equal(this.maxCapPct.toString());
      
            await expect(
              this.SevnStaking.setMaxCapPct(this.maxCapPct - 1, {from: deployer})
            ).to.be.revertedWith(
              "VeSevnStaking: expected new _maxCapPct to be greater than existing maxCapPct"
            );
          });
      
          it("should not allow owner to set maxCapPct greater than upper limit", async function () {
            await expect(
              this.SevnStaking.setMaxCapPct(10000001, {from: deployer})
            ).to.be.revertedWith(
              "VeSevnStaking: expected new _maxCapPct to be non-zero and <= 10000000"
            );
          });
      
          it("should allow owner to setMaxCapPct", async function () {
            expect(new BigNumber(await this.SevnStaking.maxCapPct()).toFixed()).to.be.equal(this.maxCapPct.toString());
      
            await this.SevnStaking
              .setMaxCapPct(this.maxCapPct + 100, {from: deployer});
      
            expect(new BigNumber(await this.SevnStaking.maxCapPct()).toFixed()).to.be.equal(
              (this.maxCapPct + 100).toString()
            );
          });

    })


    describe("setVeSevnPerSharePerSec", function () {
        it("should not allow non-owner to setVeSevnPerSharePerSec", async function () {
          await expect(
            this.SevnStaking
              .setVeSevnPerSharePerSec(web3.utils.toWei("1.5", 'ether'), {from: alice})
          ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    
        it("should not allow owner to set veJoePerSharePerSec greater than upper limit", async function () {
          await expect(
            this.SevnStaking
              .setVeSevnPerSharePerSec(web3.utils.toWei(web3.utils.toWei("1", 'ether'), 'kether'),  {from: deployer})
          ).to.be.revertedWith(
            "VeSevnStaking: expected _veSevnPerSharePerSec to be <= 1e36"
          );
        });
    
        it("should allow owner to setVeSevnPerSharePerSec", async function () {
          expect(new BigNumber(await this.SevnStaking.veSevnPerSharePerSec()).toFixed()).to.be.equal(
            this.veSevnPerSharePerSec.toString()
          );
    
          await this.SevnStaking
            .setVeSevnPerSharePerSec(web3.utils.toWei("1.5", 'ether'), {from: deployer});
    
          expect(new BigNumber(await this.SevnStaking.veSevnPerSharePerSec()).toFixed()).to.be.equal(
            web3.utils.toWei("1.5", 'ether')
          );
        });
      });


      describe("setSpeedUpThreshold", function () {
        it("should not allow non-owner to setSpeedUpThreshold", async function () {
          await expect(
            this.SevnStaking.setSpeedUpThreshold(10, {from: alice})
          ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    
        it("should not allow owner to setSpeedUpThreshold to 0", async function () {
          await expect(
            this.SevnStaking.setSpeedUpThreshold(0, {from: deployer})
          ).to.be.revertedWith(
            "VeSevnStaking: expected _speedUpThreshold to be > 0 and <= 100"
          );
        });
    
        it("should not allow owner to setSpeedUpThreshold greater than 100", async function () {
          await expect(
            this.SevnStaking.setSpeedUpThreshold(101, {from: deployer})
          ).to.be.revertedWith(
            "VeSevnStaking: expected _speedUpThreshold to be > 0 and <= 100"
          );
        });
    
        it("should allow owner to setSpeedUpThreshold", async function () {
          expect(new BigNumber(await this.SevnStaking.speedUpThreshold()).toFixed()).to.be.equal(
            this.speedUpThreshold.toString()
          );
    
          await this.SevnStaking.setSpeedUpThreshold(10, {from: deployer});
    
          expect(new BigNumber(await this.SevnStaking.speedUpThreshold()).toFixed()).to.be.equal('10');
        });
    });

    describe("deposit", function () {
        it("should not allow deposit 0", async function () {
          await expect(
            this.SevnStaking.deposit(0, {from: alice})
          ).to.be.revertedWith(
            "VeSevnStaking: expected deposit amount to be greater than zero"
          );
        });
    
        it("should have correct updated user info after first time deposit", async function () {
            const beforeAliceUserInfo = await this.SevnStaking.userInfo.call(alice);
            // balance
            expect(new BigNumber(beforeAliceUserInfo[0]).toFixed()).to.be.equal('0');
            // rewardDebt
            expect(new BigNumber(beforeAliceUserInfo[1]).toFixed()).to.be.equal('0');
            // lastClaimTimestamp
            expect(new BigNumber(beforeAliceUserInfo[2]).toFixed()).to.be.equal('0');
            // speedUpEndTimestamp
            expect(new BigNumber(beforeAliceUserInfo[3]).toFixed()).to.be.equal('0');
      
            // Check sevn balance before deposit
            expect(new BigNumber(await this.sevn.balanceOf(alice)).toFixed()).to.be.equal(
              web3.utils.toWei("1000", 'ether')
            );
      
            const depositAmount = web3.utils.toWei("100", 'ether');
            await this.SevnStaking.deposit(depositAmount, {from: alice});
            const depositBlock = await time.latest();
      
            // Check sevn balance after deposit
            expect(new BigNumber(await this.sevn.balanceOf(alice)).toFixed()).to.be.equal(
              web3.utils.toWei("900", 'ether')
            );
      
            const afterAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // balance
            expect(new BigNumber(afterAliceUserInfo[0]).toFixed()).to.be.equal(depositAmount.toString());
            // debtReward
            expect(new BigNumber(afterAliceUserInfo[1]).toFixed()).to.be.equal('0');
            // lastClaimTimestamp
            expect(new BigNumber(afterAliceUserInfo[2]).toFixed()).to.be.equal(depositBlock.toString());
            // speedUpEndTimestamp
            expect(new BigNumber(afterAliceUserInfo[3]).toFixed()).to.be.equal(
              (new BigNumber(depositBlock).plus(this.speedUpDuration).toFixed()).toString()
            );
          });

          it("should have correct updated user balance after deposit with non-zero balance", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            await this.SevnStaking
              .deposit(web3.utils.toWei("5", 'ether'), {from: alice});
      
            const afterAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // balance
            expect(new BigNumber(afterAliceUserInfo[0]).toFixed()).to.be.equal(web3.utils.toWei("105", 'ether'));
          });

          it("should claim pending veSEVN upon depositing with non-zero balance", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            await advanceTimeAndBlock(28);
      
            // Check veJoe balance before deposit
            expect(new BigNumber(await this.veSevn.balanceOf(alice)).toFixed()).to.be.equal('0');
      
            await this.SevnStaking
              .deposit(web3.utils.toWei("1", 'ether'), {from: alice});
      
            // Check veSEVN balance after deposit
            // Should have sum of:
            // baseVeSevn =  100 * 30 = 3000 veSEVN
            // speedUpVeSevn = 100 * 30 = 3000 veSEVN
            expect(new BigNumber(await this.veSevn.balanceOf(alice)).toFixed()).to.be.equal(
              web3.utils.toWei("6000", 'ether')
            );
          });

          it("should receive speed up benefits after depositing speedUpThreshold with non-zero balance", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            await advanceTimeAndBlock(this.speedUpDuration - 1);
      
            await this.SevnStaking.claim({from: alice});
      
            const afterClaimAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // speedUpTimestamp
            expect(new BigNumber(afterClaimAliceUserInfo[3]).toFixed()).to.be.equal('0');
      
            await this.SevnStaking
              .deposit(web3.utils.toWei("5", 'ether'), {from: alice});
      
            const secondDepositBlock = await time.latest();
      
            const seconDepositAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // speedUpTimestamp
            expect(new BigNumber(seconDepositAliceUserInfo[3]).toFixed()).to.be.equal(
              new BigNumber(secondDepositBlock).plus(this.speedUpDuration).toFixed()
            );
          });


          it("should not receive speed up benefits after depositing less than speedUpThreshold with non-zero balance", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            await advanceTimeAndBlock(this.speedUpDuration - 1);
      
            await this.SevnStaking
              .deposit(web3.utils.toWei("1", 'ether'), {from: alice});
      
            const afterAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // speedUpTimestamp
            expect(new BigNumber(afterAliceUserInfo[3]).toFixed()).to.be.equal('0');
          });

          it("should receive speed up benefits after deposit with zero balance", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            await advanceTimeAndBlock(99);
      
            await this.SevnStaking
              .withdraw(web3.utils.toWei("100", 'ether'), {from: alice});
      
            await advanceTimeAndBlock(99);
      
            await this.SevnStaking
              .deposit(web3.utils.toWei("1", 'ether'), {from: alice});
      
            const secondDepositBlock = await time.latest();
      
            const secondDepositAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // speedUpEndTimestamp
            expect(new BigNumber(secondDepositAliceUserInfo[3]).toFixed()).to.be.equal(
              new BigNumber(secondDepositBlock).plus(this.speedUpDuration).toFixed()
            );
          });


          it("should have speed up period extended after depositing speedUpThreshold and currently receiving speed up benefits", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            const initialDepositBlock = await time.latest();
      
            const initialDepositAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            const initialDepositSpeedUpEndTimestamp = initialDepositAliceUserInfo[3];
      
            expect(new BigNumber(initialDepositSpeedUpEndTimestamp).toFixed()).to.be.equal(
              new BigNumber(initialDepositBlock).plus(this.speedUpDuration).toFixed()
            );
      
            // Increase by some amount of time less than speedUpDuration
            await advanceTimeAndBlock(this.speedUpDuration / 2 - 1);
      
            // Deposit speedUpThreshold amount so that speed up period gets extended
            await this.SevnStaking
              .deposit(web3.utils.toWei("5", 'ether'), {from: alice});
      
            const secondDepositBlock = await time.latest();
      
            const secondDepositAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            const secondDepositSpeedUpEndTimestamp = secondDepositAliceUserInfo[3];
      
            expect(
              secondDepositSpeedUpEndTimestamp.gt(initialDepositSpeedUpEndTimestamp)
            ).to.be.equal(true);
            expect(new BigNumber(secondDepositSpeedUpEndTimestamp).toFixed()).to.be.equal(
              new BigNumber(secondDepositBlock).plus(this.speedUpDuration).toFixed()
            );
          });

          it("should have lastClaimTimestamp updated after depositing if holding max veSEVN cap", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            // Increase by `maxCapPct` seconds to ensure that user will have max veSEVN
            // after claiming
            await advanceTimeAndBlock(this.maxCapPct - 1);
      
            await this.SevnStaking.claim({from: alice});
      
            const claimBlock = await time.latest();
      
            const claimAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // lastClaimTimestamp
            expect(new BigNumber(claimAliceUserInfo[2]).toFixed()).to.be.equal(claimBlock.toString());
      
            await advanceTimeAndBlock(this.maxCapPct - 1);
      
            const pendingVeSevn = await this.SevnStaking.getPendingVeSevn(
              alice
            );
            expect(web3.utils.fromWei(pendingVeSevn, 'ether')).to.be.equal('0');
      
            await this.SevnStaking
              .deposit(web3.utils.toWei("5", 'ether'), {from: alice});
      
            const secondDepositBlock = await time.latest();
      
            const secondDepositAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // lastClaimTimestamp
            expect(new BigNumber(secondDepositAliceUserInfo[2]).toFixed()).to.be.equal(
              new BigNumber(secondDepositBlock).toFixed()
            );
          });
    });

    describe("withdraw", function () {
        it("should not allow withdraw 0", async function () {
          await expect(
            this.SevnStaking.withdraw(0, {from: alice})
          ).to.be.revertedWith(
            "VeSevnStaking: expected withdraw amount to be greater than zero"
          );
        });

        it("should not allow withdraw amount greater than user balance", async function () {
            await expect(
              this.SevnStaking.withdraw(1, {from: alice})
            ).to.be.revertedWith(
              "VeSevnStaking: cannot withdraw greater amount of SEVN than currently staked"
            );
          });


          it("should have correct updated user info and balances after withdraw", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
            const depositBlock = await time.latest();
      
            expect(new BigNumber(await this.sevn.balanceOf(alice)).toFixed()).to.be.equal(
              new BigNumber(web3.utils.toWei("900", 'ether')).toFixed()
            );
      
            await advanceTimeAndBlock(this.speedUpDuration / 2 - 1);
      
            await this.SevnStaking.claim({from: alice});
            const claimBlock = await time.latest();
      
            expect(new BigNumber(await this.veSevn.balanceOf(alice)).toFixed()).to.not.be.equal('0');
      
            const beforeAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // balance
            expect(new BigNumber(beforeAliceUserInfo[0]).toFixed()).to.be.equal(
              new BigNumber(web3.utils.toWei("100", 'ether')).toFixed()
            );
            // rewardDebt
            expect(new BigNumber(beforeAliceUserInfo[1]).toFixed()).to.be.equal(
              // Divide by 2 since half of it is from the speed up
              new BigNumber(await this.veSevn.balanceOf(alice)).dividedBy(2).toFixed()
            );
            // lastClaimTimestamp
            expect(new BigNumber(beforeAliceUserInfo[2]).toFixed()).to.be.equal(new BigNumber(claimBlock).toFixed());
            // speedUpEndTimestamp
            expect(new BigNumber(beforeAliceUserInfo[3]).toFixed()).to.be.equal(
              new BigNumber(depositBlock).plus(this.speedUpDuration).toFixed()
            );
      
            await this.SevnStaking
              .withdraw(web3.utils.toWei("5", 'ether'), {from: alice});
            const withdrawBlock = await time.latest();
      
            // Check user info fields are updated correctly
            const afterAliceUserInfo = await this.SevnStaking.userInfo.call(
              alice
            );
            // balance
            expect(new BigNumber(afterAliceUserInfo[0]).toFixed()).to.be.equal(new BigNumber(web3.utils.toWei("95", 'ether')).toFixed());
            // rewardDebt
            expect(new BigNumber(afterAliceUserInfo[1]).toFixed()).to.be.equal(
              new BigNumber(await this.SevnStaking.accVeSevnPerShare()).multipliedBy(95).toFixed()
            );
            // lastClaimTimestamp
            expect(new BigNumber(afterAliceUserInfo[2]).toFixed()).to.be.equal(new BigNumber(withdrawBlock).toFixed());
            // speedUpEndTimestamp
            expect(new BigNumber(afterAliceUserInfo[3]).toFixed()).to.be.equal('0');
      
            // Check user token balances are updated correctly
            expect(new BigNumber(await this.veSevn.balanceOf(alice)).toFixed()).to.be.equal('0');
            expect(new BigNumber(await this.sevn.balanceOf(alice)).toFixed()).to.be.equal(
              new BigNumber(web3.utils.toWei("905", 'ether')).toFixed()
            );
          });

    });

    describe("claim", function () {
        it("should not be able to claim with zero balance", async function () {
          await expect(
            this.SevnStaking.claim({from: alice})
          ).to.be.revertedWith(
            "VeSevnStaking: cannot claim veSEVN when no SEVN is staked"
          );
        }); 

        it("should update lastRewardTimestamp on claim", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            await advanceTimeAndBlock(99);
      
            await this.SevnStaking.claim({from: alice});
            const claimBlock = await time.latest();
      
            // lastRewardTimestamp
            expect(new BigNumber(await this.SevnStaking.lastRewardTimestamp()).toFixed()).to.be.equal(
              new BigNumber(claimBlock).toFixed()
            );
          });

          it("should receive veSEVN on claim", async function () {
            await this.SevnStaking
              .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            await advanceTimeAndBlock(48);
      
            // Check veJoe balance before claim
            expect(new BigNumber(await this.veSevn.balanceOf(alice)).toFixed()).to.be.equal('0');
      
            await this.SevnStaking.claim({from: alice});
      
            // Check veJoe balance after claim
            // Should be sum of:
            // baseVeJoe = 100 * 50 = 5000
            // speedUpVeJoe = 100 * 50 = 5000
            expect(new BigNumber(await this.veSevn.balanceOf(alice)).toFixed()).to.be.equal(
              new BigNumber(web3.utils.toWei("10000", 'ether')).toFixed()
            );
          });

          it("should receive correct veSEVN if veSevnPerSharePerSec is updated multiple times", async function () {
            await this.SevnStaking.deposit(web3.utils.toWei("100", 'ether'), {from: alice});
      
            await advanceTimeAndBlock(8);
      
            await this.SevnStaking.setVeSevnPerSharePerSec(web3.utils.toWei("2", 'ether'), {from: deployer});
      
            await advanceTimeAndBlock(8);
      
            await this.SevnStaking.setVeSevnPerSharePerSec(web3.utils.toWei("1.5", 'ether'), {from: deployer});
      
            await advanceTimeAndBlock(8);
      
            // Check veSevn balance before claim
            expect(new BigNumber(await this.veSevn.balanceOf(alice)).toFixed()).to.be.equal('0');
      
            await this.SevnStaking.claim({from: alice});
      
            // Check veSevn balance after claim
            // For baseVeSevn, we're expected to have been generating at a rate of 1 for
            // the first 10 seconds, a rate of 2 for the next 10 seconds, and a rate of
            // 1.5 for the last 10 seconds, i.e.:
            // baseVeSevn = 100 * 10 * 1 + 100 * 10 * 2 + 100 * 10 * 1.5 = 4500
            // speedUpVeSevn = 100 * 30 = 3000
            expect(new BigNumber(await this.veSevn.balanceOf(alice)).toFixed()).to.be.equal(
              new BigNumber(web3.utils.toWei("7500", 'ether')).toFixed()
            );
          });

    });

    describe("updateRewardVars", function () {
        it("should have correct reward vars after time passes", async function () {
          await this.SevnStaking
            .deposit(web3.utils.toWei("100", 'ether'), {from: alice});
    
          const block = await time.latest();
          await advanceTimeAndBlock(28);
    
          const accVeSevnPerShareBeforeUpdate =
            await this.SevnStaking.accVeSevnPerShare();
          await this.SevnStaking.updateRewardVars({from: deployer});
    
          expect(new BigNumber(await this.SevnStaking.lastRewardTimestamp()).toFixed()).to.be.equal(
            new BigNumber(block).plus(30).toFixed()
          );
          // Increase should be `secondsElapsed * veSevnPerSharePerSec * ACC_VESEVN_PER_SHARE_PER_SEC_PRECISION`:
          // = 30 * 1 * 1e18
          expect(new BigNumber(await this.SevnStaking.accVeSevnPerShare()).toFixed()).to.be.equal(
            new BigNumber(accVeSevnPerShareBeforeUpdate).plus(new BigNumber(web3.utils.toWei("30", 'ether'))).toFixed()
          );
        });
      });

    describe("setupBoostedMasterChef", function () {

        it('setup', async function(){
            expect(await this.SevnStaking.boostedMasterChef.call()).to.be.equal('0x0000000000000000000000000000000000000000')
            await expect(this.SevnStaking.setBoostedMasterChefSevn('0x0000000000000000000000000000000000000000', {from:alice})).to.be.revertedWith("Ownable: caller is not the owner")
            await this.SevnStaking.setBoostedMasterChefSevn(bob, {from: deployer})
            expect(await this.SevnStaking.boostedMasterChef.call()).to.be.equal(bob)
        })

    });

    async function advanceTimeAndBlock(duration) {
        await time.increase(duration)
        await time.advanceBlock()
      }
      
})  