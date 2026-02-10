const fs = require("fs");
const { Octokit } = require("@octokit/rest");
const sodium = require("libsodium-wrappers");

const GITHUB_TOKEN = "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";
const GITHUB_REPO_OWNER = "Lakisa-code";
const GITHUB_REPO_NAME = "gavra_android";

const octokit = new Octokit({ auth: GITHUB_TOKEN });

async function encryptSecret(publicKey, secretValue) {
    await sodium.ready;

    const binaryString = Buffer.from(publicKey, "base64").toString("binary");
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }

    const encrypted = sodium.crypto_box_seal(secretValue, bytes);
    return Buffer.from(encrypted).toString("base64");
}

async function getPublicKey() {
    const response = await octokit.rest.actions.getRepoPublicKey({
        owner: GITHUB_REPO_OWNER,
        repo: GITHUB_REPO_NAME,
    });
    return response.data;
}

async function setSecret(publicKey, secretName, secretValue) {
    const encrypted = await encryptSecret(publicKey.key, secretValue);

    await octokit.rest.actions.createOrUpdateRepoSecret({
        owner: GITHUB_REPO_OWNER,
        repo: GITHUB_REPO_NAME,
        secret_name: secretName,
        encrypted_value: encrypted,
        key_id: publicKey.key_id,
    });

    console.log(`✅ Updated: ${secretName} (length: ${secretValue.length})`);
}

async function main() {
    try {
        const publicKey = await getPublicKey();
        console.log(`🔑 Using public key: ${publicKey.key_id}\n`);

        // Pročitaj fajlove
        const playKeyJson = fs.readFileSync("../google-play-key.json", "utf8");
        const keystoreBuffer = fs.readFileSync("../android/gavra-release-key-production.keystore");

        // Konveruj u Base64
        const playKeyB64 = Buffer.from(playKeyJson).toString("base64");
        const keystoreB64 = keystoreBuffer.toString("base64");

        console.log(`📊 Play Key B64 size: ${playKeyB64.length} chars`);
        console.log(`📊 Keystore B64 size: ${keystoreB64.length} chars\n`);

        // Postavi secrets
        await setSecret(publicKey, "GOOGLE_PLAY_KEY_B64", playKeyB64);
        await setSecret(publicKey, "ANDROID_KEYSTORE_B64", keystoreB64);
        await setSecret(publicKey, "ANDROID_KEYSTORE_PASSWORD", "GavraRelease2024");
        await setSecret(publicKey, "ANDROID_KEY_PASSWORD", "GavraRelease2024");
        await setSecret(publicKey, "ANDROID_KEY_ALIAS", "gavra-release-key");

        console.log("\n✨ Svi secrets su ažurirani!");

    } catch (error) {
        console.error("❌ Error:", error.message);
        process.exit(1);
    }
}

main();
