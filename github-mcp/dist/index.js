#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import { Octokit } from "@octokit/rest";
import "dotenv/config.js";
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO_OWNER = process.env.GITHUB_REPO_OWNER || "lakisa-code";
const REPO_NAME = process.env.GITHUB_REPO_NAME || "gavra_android";
if (!GITHUB_TOKEN) {
    console.error("❌ Missing required environment variable: GITHUB_TOKEN");
    process.exit(1);
}
const octokit = new Octokit({
    auth: GITHUB_TOKEN,
});
const tools = [
    {
        name: "github_set_secret",
        description: "Set or update a GitHub repository secret",
        inputSchema: {
            type: "object",
            properties: {
                secret_name: {
                    type: "string",
                    description: "Name of the secret (e.g., GOOGLE_PLAY_KEY_B64)",
                },
                secret_value: {
                    type: "string",
                    description: "Value of the secret (will be encrypted)",
                },
            },
            required: ["secret_name", "secret_value"],
        },
    },
    {
        name: "github_list_secrets",
        description: "List all secrets in the repository",
        inputSchema: {
            type: "object",
            properties: {},
            required: [],
        },
    },
    {
        name: "github_delete_secret",
        description: "Delete a secret from the repository",
        inputSchema: {
            type: "object",
            properties: {
                secret_name: {
                    type: "string",
                    description: "Name of the secret to delete",
                },
            },
            required: ["secret_name"],
        },
    },
    {
        name: "github_set_secrets_batch",
        description: "Set multiple secrets at once",
        inputSchema: {
            type: "object",
            properties: {
                secrets: {
                    type: "object",
                    description: "Object with secret names as keys and values as secret values",
                },
            },
            required: ["secrets"],
        },
    },
];
async function setSecret(secretName, secretValue) {
    try {
        // Get public key for encryption
        const publicKeyResponse = await octokit.rest.actions.getRepoPublicKey({
            owner: REPO_OWNER,
            repo: REPO_NAME,
        });
        const publicKey = publicKeyResponse.data.key;
        const keyId = publicKeyResponse.data.key_id;
        // Encrypt the secret value using libsodium
        const sodium = require("libsodium-wrappers");
        await sodium.ready;
        const encryptedSecret = Buffer.from(sodium.crypto_box_seal(secretValue, Buffer.from(publicKey, "base64"))).toString("base64");
        // Create or update the secret
        await octokit.rest.actions.createOrUpdateRepoSecret({
            owner: REPO_OWNER,
            repo: REPO_NAME,
            secret_name: secretName,
            encrypted_value: encryptedSecret,
            key_id: keyId,
        });
        return `✅ Secret '${secretName}' has been set successfully`;
    }
    catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        throw new Error(`Failed to set secret: ${errorMsg}`);
    }
}
async function listSecrets() {
    try {
        const response = await octokit.rest.actions.listRepoSecrets({
            owner: REPO_OWNER,
            repo: REPO_NAME,
        });
        if (!response.data.secrets || response.data.secrets.length === 0) {
            return "No secrets found in the repository";
        }
        const secretsList = response.data.secrets
            .map((secret) => `• ${secret.name} (updated: ${new Date(secret.updated_at).toLocaleDateString()})`)
            .join("\n");
        return `📋 Secrets in ${REPO_OWNER}/${REPO_NAME}:\n\n${secretsList}`;
    }
    catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        throw new Error(`Failed to list secrets: ${errorMsg}`);
    }
}
async function deleteSecret(secretName) {
    try {
        await octokit.rest.actions.deleteRepoSecret({
            owner: REPO_OWNER,
            repo: REPO_NAME,
            secret_name: secretName,
        });
        return `✅ Secret '${secretName}' has been deleted successfully`;
    }
    catch (error) {
        const errorMsg = error instanceof Error ? error.message : String(error);
        throw new Error(`Failed to delete secret: ${errorMsg}`);
    }
}
async function setSecretsBatch(secrets) {
    const results = [];
    for (const [name, value] of Object.entries(secrets)) {
        try {
            const result = await setSecret(name, value);
            results.push(result);
        }
        catch (error) {
            results.push(`❌ Failed to set '${name}': ${error instanceof Error ? error.message : String(error)}`);
        }
    }
    return results.join("\n");
}
async function handleToolCall(toolName, toolInput) {
    switch (toolName) {
        case "github_set_secret": {
            const secretName = toolInput.secret_name;
            const secretValue = toolInput.secret_value;
            return await setSecret(secretName, secretValue);
        }
        case "github_list_secrets": {
            return await listSecrets();
        }
        case "github_delete_secret": {
            const secretName = toolInput.secret_name;
            return await deleteSecret(secretName);
        }
        case "github_set_secrets_batch": {
            const secrets = toolInput.secrets;
            return await setSecretsBatch(secrets);
        }
        default:
            throw new Error(`Unknown tool: ${toolName}`);
    }
}
async function main() {
    const server = new Server({
        name: "github-mcp",
        version: "1.0.0",
    }, {
        capabilities: {
            tools: {},
        },
    });
    server.setRequestHandler(ListToolsRequestSchema, async () => ({
        tools,
    }));
    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        const name = request.params.name;
        const args = request.params.arguments || {};
        try {
            const result = await handleToolCall(name, args);
            return {
                content: [
                    {
                        type: "text",
                        text: result,
                    },
                ],
            };
        }
        catch (error) {
            return {
                content: [
                    {
                        type: "text",
                        text: `Error: ${error instanceof Error ? error.message : String(error)}`,
                    },
                ],
                isError: true,
            };
        }
    });
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("✅ GitHub MCP server started successfully");
}
main().catch(console.error);
//# sourceMappingURL=index.js.map