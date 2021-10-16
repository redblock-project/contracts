const deploy = require("./deployer");

const main = async () => {
  await deploy("RedblockComrades");
};

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
