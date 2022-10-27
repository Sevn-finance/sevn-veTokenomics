const web3 = require('web3');

const VeSevnStaking = artifacts.require("VeSevnStaking");

module.exports = async function (deployer) {

  const sevn = '';
  const veSevn = '';
  const veSevnPerSharePerSec = web3.utils.fromWei('3170979198376', 'ether') ; // 0.000003215020576 veSevn 
  const speedUpVeSevnPerSharePerSec = web3.utils.fromWei('3170979198376', 'ether'); // 0.000003215020576  + 0.000003215020576 veSevn  =  0.000006430041152 veSevn
  const speedUpThreshold = 5; // 5% 
  const speedUpDuration = 1296000; // 15 days
  const maxCapPct = 10000; // sevn * 100 || 10000%

  await deployer.deploy(
    VeSevnStaking, 
    sevn, 
    veSevn, 
    veSevnPerSharePerSec, 
    speedUpVeSevnPerSharePerSec, 
    speedUpThreshold, 
    speedUpDuration, 
    maxCapPct
  );
};
