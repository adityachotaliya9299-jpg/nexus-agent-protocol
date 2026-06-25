// ============================================================
// Phase 10 — Operator Registration Script
// ============================================================
// Helps an EigenLayer operator register with the Nexus AVS.
//
// Steps:
//  1. Operator signs the EIP-712 registration digest
//  2. Owner submits the signature via NexusServiceManager
//
// Usage (operator side — signs the digest):
//   node scripts/avs/register-operator.js sign \
//     --operator 0xYourOperatorAddress \
//     --service-manager 0xNexusServiceManager \
//     --private-key 0xYourPrivateKey \
//     --rpc-url https://sepolia.infura.io/v3/YOUR_KEY
//
// Usage (owner side — submits the registration):
//   node scripts/avs/register-operator.js register \
//     --operator 0xOperatorAddress \
//     --signature 0xSignatureFromAbove \
//     --salt 0xSalt \
//     --expiry 1234567890 \
//     --agent-id 42 \
//     --service-manager 0xNexusServiceManager \
//     --private-key 0xOwnerPrivateKey \
//     --rpc-url https://sepolia.infura.io/v3/YOUR_KEY
// ============================================================

const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

// ── ABIs (minimal) ──
const SERVICE_MANAGER_ABI = [
  "function getOperatorRegistrationDigest(address operator, bytes32 salt, uint256 expiry) view returns (bytes32)",
  "function registerOperatorToAVS(address operator, tuple(bytes signature, bytes32 salt, uint256 expiry) operatorSignature, uint256 agentId) external",
  "function isNexusOperator(address) view returns (bool)",
  "function isRegisteredInEigenLayer(address) view returns (bool)",
  "function getOperatorCount() view returns (uint256)",
  "function avsMetadataURI() view returns (string)",
];

async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || !["sign", "register", "status"].includes(command)) {
    console.log(`
Usage:
  node register-operator.js sign     --operator <addr> --service-manager <addr> --private-key <key> --rpc-url <url>
  node register-operator.js register --operator <addr> --signature <sig> --salt <salt> --expiry <ts> --agent-id <id> --service-manager <addr> --private-key <key> --rpc-url <url>
  node register-operator.js status   --service-manager <addr> --rpc-url <url>
    `);
    process.exit(1);
  }

  // Parse args into a map
  const opts = {};
  for (let i = 1; i < args.length; i += 2) {
    opts[args[i].replace("--", "")] = args[i + 1];
  }

  const provider = new ethers.JsonRpcProvider(opts["rpc-url"]);
  const sm = new ethers.Contract(opts["service-manager"], SERVICE_MANAGER_ABI, provider);

  // ── SIGN ──
  if (command === "sign") {
    const operator = opts["operator"];
    const salt = ethers.randomBytes(32);
    const saltHex = ethers.hexlify(salt);
    const expiry = Math.floor(Date.now() / 1000) + 86400; // 24h from now

    console.log("==========================================");
    console.log("Signing EigenLayer AVS Registration");
    console.log("==========================================");
    console.log("Operator:        ", operator);
    console.log("ServiceManager:  ", opts["service-manager"]);
    console.log("Salt:            ", saltHex);
    console.log("Expiry:          ", expiry, "(", new Date(expiry * 1000).toISOString(), ")");

    // Get the digest from the contract
    const digest = await sm.getOperatorRegistrationDigest(operator, saltHex, expiry);
    console.log("Digest:          ", digest);

    // Sign the digest with the operator's key
    const signer = new ethers.Wallet(opts["private-key"], provider);
    if (signer.address.toLowerCase() !== operator.toLowerCase()) {
      console.error("ERROR: Private key does not match operator address");
      console.error("  Key address:", signer.address);
      console.error("  Operator:   ", operator);
      process.exit(1);
    }

    const signature = await signer.signMessage(ethers.getBytes(digest));
    console.log("");
    console.log("Signature:       ", signature);
    console.log("");
    console.log("==========================================");
    console.log("Give these to the protocol owner to register:");
    console.log("  --operator   ", operator);
    console.log("  --signature  ", signature);
    console.log("  --salt       ", saltHex);
    console.log("  --expiry     ", expiry);
    console.log("==========================================");

    // Save to file for easy handoff
    const output = { operator, signature, salt: saltHex, expiry, digest };
    const outPath = path.join(__dirname, "operator-registration.json");
    fs.writeFileSync(outPath, JSON.stringify(output, null, 2));
    console.log("Saved to: scripts/avs/operator-registration.json");
  }

  // ── REGISTER ──
  if (command === "register") {
    const ownerWallet = new ethers.Wallet(opts["private-key"], provider);
    const smWithSigner = sm.connect(ownerWallet);

    const operator  = opts["operator"];
    const signature = opts["signature"];
    const salt      = opts["salt"];
    const expiry    = Number(opts["expiry"]);
    const agentId   = Number(opts["agent-id"] || "0");

    console.log("==========================================");
    console.log("Registering Operator to Nexus AVS");
    console.log("==========================================");
    console.log("Owner:           ", ownerWallet.address);
    console.log("Operator:        ", operator);
    console.log("AgentId:         ", agentId);

    const tx = await smWithSigner.registerOperatorToAVS(
      operator,
      { signature, salt, expiry },
      agentId
    );
    console.log("TX sent:         ", tx.hash);
    const receipt = await tx.wait();
    console.log("Confirmed block: ", receipt.blockNumber);

    // Verify registration
    const isRegistered = await sm.isRegisteredInEigenLayer(operator);
    const count = await sm.getOperatorCount();
    console.log("");
    console.log("EigenLayer registered:", isRegistered ? "✓ YES" : "✗ NO");
    console.log("Total Nexus operators:", count.toString());
    console.log("==========================================");
  }

  // ── STATUS ──
  if (command === "status") {
    const count = await sm.getOperatorCount();
    const metaURI = await sm.avsMetadataURI();

    console.log("==========================================");
    console.log("Nexus AVS Status");
    console.log("==========================================");
    console.log("ServiceManager:      ", opts["service-manager"]);
    console.log("Registered Operators:", count.toString());
    console.log("Metadata URI:        ", metaURI);
    console.log("==========================================");
  }

  process.exit(0);
}

main().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});