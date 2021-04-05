const { expect } = require("chai");

describe("StrategistProfiterBSCV2", function() {
  let profiter;
  it("Should deploy profiter", async function() {
    const StrategistProfiterBSCV2 = await ethers.getContractFactory("StrategistProfiterBSCV2");
    profiter = await StrategistProfiterBSCV2.deploy();
    await profiter.deployed();
  });
  it("Should clone profiter", async function() {
    await profiter.clone();
  });
});
