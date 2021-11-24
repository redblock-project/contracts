const deploy = require("./deployer");

const main = async () => {
  // const punks = await deploy("NFTMock");
  // const meebits = await deploy("NFTMock");
  // const veeFriends = await deploy("NFTMock");

  // const nct = await deploy("ERC20Mock", "NCT", "NCT", 18);
  // const dust = await deploy("ERC20Mock", "DUST", "DUST", 18);
  // const whale = await deploy("ERC20Mock", "WHALE", "WHALE", 4);

  // const nftBoxes = await deploy("NFTMock");
  // const artblocks = await deploy("NFTMock");

  await deploy(
    "RedblockComrades",
    [
      "0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB",
      "0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7",
      "0xa3aee8bce55beea1951ef834b99f3ac60d1abeeb",
    ],
    [
      "0x8A9c4dfe8b9D8962B31e4e16F8321C44d48e246E",
      "0xe2E109f1b4eaA8915655fE8fDEfC112a34ACc5F0",
      "0x9355372396e3F6daF13359B7b607a3374cc638e0",
    ],
    ["0x6d4530149e5B4483d2F7E60449C02570531A0751", "0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270"]
  );
};

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
