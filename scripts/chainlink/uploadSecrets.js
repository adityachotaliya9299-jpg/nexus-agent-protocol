// ============================================================
// Phase 16 — Upload Encrypted Secrets to Chainlink DON
// ============================================================
// This script uploads your OpenAI API key as an encrypted secret
// to the Chainlink DON, so the JS source can call the LLM API.
//
// Prerequisites:
//   npm install @chainlink/functions-toolkit dotenv ethers
//
// Setup:
//   1. Create a .env file (never commit):
//      PRIVATE_KEY=0x...
//      SEPOLIA_RPC_URL=https://...
//      OPENAI_API_KEY=sk-...
//      CHAINLINK_SUB_ID=12345
//      INFERENCE_ADDR=0x...
//
//   2. Run:
//      node scripts/chainlink/uploadSecrets.js
//
//   3. Copy the returned encryptedSecretsRef bytes
//
//   4. Call setEncryptedSecretsRef() on your deployed contract:
//      cast send $INFERENCE_ADDR "setEncryptedSecretsRef(bytes)" \
//        <encryptedSecretsRef> \
//        --rpc-url $SEPOLIA_RPC_URL \
//        --private-key $PRIVATE_KEY
// ============================================================

const { SecretsManager } = require("@chainlink/functions-toolkit");
const { ethers } = require("ethers");
require("dotenv").config();

const ROUTER_ADDRESS   = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0";
const DON_ID           = "fun-ethereum-sepolia-1";
const GATEWAY_URLS     = [
    "https://01.functions-gateway.testnet.chain.link/",
    "https://02.functions-gateway.testnet.chain.link/"
];
const SECRETS_EXPIRY   = 60 * 60 * 24 * 7; // 7 days in seconds
const INFERENCE_ABI    = [
    "function setEncryptedSecretsRef(bytes calldata _ref) external"
];

async function main() {
    const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
    const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

    const subId         = parseInt(process.env.CHAINLINK_SUB_ID);
    const inferenceAddr = process.env.INFERENCE_ADDR;
    const openaiKey     = process.env.OPENAI_API_KEY;

    if (!openaiKey) throw new Error("OPENAI_API_KEY not set in .env");
    if (!subId)     throw new Error("CHAINLINK_SUB_ID not set in .env");
    if (!inferenceAddr) throw new Error("INFERENCE_ADDR not set in .env");

    console.log("==========================================");
    console.log("Uploading secrets to Chainlink DON");
    console.log("==========================================");
    console.log("Signer:       ", wallet.address);
    console.log("SubID:        ", subId);
    console.log("InferenceAddr:", inferenceAddr);

    // Initialize SecretsManager
    const secretsManager = new SecretsManager({
        signer:              wallet,
        functionsRouterAddress: ROUTER_ADDRESS,
        donId:               DON_ID,
    });
    await secretsManager.initialize();

    // Encrypt secrets
    const secrets = { apiKey: openaiKey };
    console.log("\nEncrypting secrets...");

    const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets);

    // Upload to DON
    console.log("Uploading to DON gateways...");
    const { version, success } = await secretsManager.uploadEncryptedSecretsToDON({
        encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
        gatewayUrls:               GATEWAY_URLS,
        slotId:                    0,
        minutesUntilExpiration:    SECRETS_EXPIRY / 60,
    });

    if (!success) throw new Error("Upload failed");

    console.log("Secrets uploaded successfully!");
    console.log("  Version:", version);

    // Build the encrypted secrets reference
    const encryptedSecretsRef = secretsManager.buildDONHostedEncryptedSecretsReference({
        slotId:  0,
        version: version,
    });

    console.log("\nencryptedSecretsRef:", encryptedSecretsRef);

    // Auto-set on the contract
    console.log("\nSetting encryptedSecretsRef on contract...");
    const inferenceContract = new ethers.Contract(inferenceAddr, INFERENCE_ABI, wallet);
    const tx = await inferenceContract.setEncryptedSecretsRef(encryptedSecretsRef);
    await tx.wait();

    console.log("Set! TX:", tx.hash);
    console.log("==========================================");
    console.log("Done. Your contract is ready to call the LLM.");
    console.log("Test with:");
    console.log(`  cast send ${inferenceAddr} \\`);
    console.log(`    "requestInference(uint256,string,bytes32)" \\`);
    console.log(`    1 "What is 2+2?" 0x0 \\`);
    console.log(`    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY`);
    console.log("==========================================");
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});