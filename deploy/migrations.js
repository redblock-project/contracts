const deploy = require("./deployer");

const main = async () => {
  const punks = await deploy("NFTMock");
  const meebits = await deploy("NFTMock");
  const veeFriends = await deploy("NFTMock");

  const nct = await deploy("ERC20Mock", "NCT", "NCT", 18);
  const dust = await deploy("ERC20Mock", "DUST", "DUST", 18);
  const whale = await deploy("ERC20Mock", "WHALE", "WHALE", 4);

  const nftBoxes = await deploy("NFTMock");
  const artblocks = await deploy("NFTMock");

  await deploy(
    "RedblockComrades",
    [punks.address, meebits.address, veeFriends.address],
    [nct.address, dust.address, whale.address],
    [nftBoxes.address, artblocks.address]
  );
};

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
