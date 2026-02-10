#!/usr/bin/env node

import { Octokit } from "@octokit/rest";
import fs from "fs";
import * as sodium from "libsodium-wrappers";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
import dotenv from "dotenv";
dotenv.config({ path: path.join(__dirname, ".env") });

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_REPO_OWNER = process.env.GITHUB_REPO_OWNER || "lakisa-code";
const GITHUB_REPO_NAME = process.env.GITHUB_REPO_NAME || "gavra_android";

if (!GITHUB_TOKEN) {
    console.error("❌ GITHUB_TOKEN nije postavljen u .env");
    process.exit(1);
}

const octokit = new Octokit({ auth: GITHUB_TOKEN });

// Učitavamo Base64 vrednosti
const playKeyB64 = fs.readFileSync("C:\\temp\\play_key_b64.txt", "utf8");
const keystoreB64 = fs.readFileSync("C:\\temp\\keystore_b64.txt", "utf8");

const secrets = {
    GOOGLE_PLAY_KEY_B64: playKeyB64,
    ANDROID_KEYSTORE_B64: keystoreB64,
    ANDROID_KEYSTORE_PASSWORD: "GavraRelease2024",
    ANDROID_KEY_PASSWORD: "GavraRelease2024",
    ANDROID_KEY_ALIAS: "gavra-release-key",
};

async function encryptSecret(publicKey, secretValue) {
    await sodium.ready;

    const binaryString = atob(publicKey);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }

    const encrypted = sodium.crypto_box_seal(secretValue, bytes);
    return Buffer.from(encrypted).toString("base64");
}

async function getPublicKey() {
    try {
        const response = await octokit.rest.actions.getRepoPublicKey({
            owner: GITHUB_REPO_OWNER,
            repo: GITHUB_REPO_NAME,
        });
        return response.data;
    } catch (error) {
        console.error("❌ Greška pri učitavanju GitHub javnog ključa:", error.message);
        throw error;
    }
}

async function setSecret(publicKey, secretName, secretValue) {
    try {
        const encrypted = await encryptSecret(publicKey.key, secretValue);

        await octokit.rest.actions.createOrUpdateRepoSecret({
            owner: GITHUB_REPO_OWNER,
            repo: GITHUB_REPO_NAME,
            secret_name: secretName,
            encrypted_value: encrypted,
            key_id: publicKey.key_id,
        });

        console.log(`✅ Secret postavljeno: ${secretName}`);
    } catch (error) {
        console.error(`❌ Greška pri postavljanju ${secretName}:`, error.message);
        throw error;
    }
}

async function main() {
    try {
        console.log("🔐 GitHub Secrets Setup - Počinje postavljanje tajni...\n");
        console.log(`📦 Repository: ${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}\n`);

        const publicKey = await getPublicKey();
        console.log(`🔑 Učitan javni ključ: ${publicKey.key_id}\n`);

        console.log("📝 Postavljam tajne:\n");

        for (const [name, value] of Object.entries(secrets)) {
            await setSecret(publicKey, name, value);
        }

        console.log("\n✨ Sve tajne su uspešno postavljene!");
        console.log("\n🚀 GitHub Actions workflow je sada spreman za pokretanje.");

    } catch (error) {
        console.error("\n❌ Postavka tajni je neuspešna:", error);
        process.exit(1);
    }
}

main();
