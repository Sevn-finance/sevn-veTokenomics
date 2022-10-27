const VeSevn = artifacts.require("VeSevn");

module.exports = async function (deployer) {
  await deployer.deploy(VeSevn);
};
