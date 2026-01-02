#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import jwt from "jsonwebtoken";
import fetch from "node-fetch";
const ISSUER_ID = process.env.APP_STORE_ISSUER_ID;
const KEY_ID = process.env.APP_STORE_KEY_ID;
const PRIVATE_KEY = process.env.APP_STORE_PRIVATE_KEY;
const APP_ID = process.env.APP_STORE_APP_ID || "6740227083"; // Gavra app ID
const BUNDLE_ID = process.env.APP_STORE_BUNDLE_ID || "com.gavra013.gavraAndroid";
const BASE_URL = "https://api.appstoreconnect.apple.com/v1";
function generateToken() {
    if (!ISSUER_ID || !KEY_ID || !PRIVATE_KEY) {
        throw new Error("Missing App Store Connect credentials (ISSUER_ID, KEY_ID, or PRIVATE_KEY)");
    }
    const now = Math.floor(Date.now() / 1000);
    const payload = {
        iss: ISSUER_ID,
        iat: now,
        exp: now + 20 * 60, // 20 minutes
        aud: "appstoreconnect-v1",
    };
    return jwt.sign(payload, PRIVATE_KEY, {
        algorithm: "ES256",
        header: {
            alg: "ES256",
            kid: KEY_ID,
            typ: "JWT",
        },
    });
}
async function apiRequest(endpoint) {
    const token = generateToken();
    const response = await fetch(`${BASE_URL}${endpoint}`, {
        headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
        },
    });
    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`App Store Connect API error: ${response.status} - ${errorText}`);
    }
    return response.json();
}
async function apiPatchRequest(endpoint, body) {
    const token = generateToken();
    const response = await fetch(`${BASE_URL}${endpoint}`, {
        method: "PATCH",
        headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
    });
    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`App Store Connect API error: ${response.status} - ${errorText}`);
    }
    return response.json();
}
// Status descriptions for App Store
function getAppStoreStateDescription(state) {
    const stateMap = {
        ACCEPTED: "Accepted - Ready for distribution",
        DEVELOPER_REJECTED: "Developer Rejected",
        DEVELOPER_REMOVED_FROM_SALE: "Removed from Sale by Developer",
        IN_REVIEW: "In Review by Apple",
        INVALID_BINARY: "Invalid Binary",
        METADATA_REJECTED: "Metadata Rejected",
        PENDING_APPLE_RELEASE: "Pending Apple Release",
        PENDING_CONTRACT: "Pending Contract",
        PENDING_DEVELOPER_RELEASE: "Pending Developer Release",
        PREPARE_FOR_SUBMISSION: "Prepare for Submission",
        PREORDER_READY_FOR_SALE: "Preorder Ready for Sale",
        PROCESSING_FOR_APP_STORE: "Processing for App Store",
        READY_FOR_REVIEW: "Ready for Review",
        READY_FOR_SALE: "Ready for Sale (LIVE)",
        REJECTED: "Rejected by Apple",
        REMOVED_FROM_SALE: "Removed from Sale",
        WAITING_FOR_EXPORT_COMPLIANCE: "Waiting for Export Compliance",
        WAITING_FOR_REVIEW: "Waiting for Review",
        REPLACED_WITH_NEW_VERSION: "Replaced with New Version",
    };
    return stateMap[state] || state;
}
function getBetaReviewStateDescription(state) {
    const stateMap = {
        WAITING_FOR_REVIEW: "Waiting for Beta Review",
        IN_REVIEW: "In Beta Review",
        REJECTED: "Beta Rejected",
        APPROVED: "Beta Approved",
    };
    return stateMap[state] || state;
}
function getProcessingStateDescription(state) {
    const stateMap = {
        PROCESSING: "Processing",
        FAILED: "Processing Failed",
        INVALID: "Invalid",
        VALID: "Valid - Ready for Testing",
    };
    return stateMap[state] || state;
}
const server = new Server({
    name: "appstore-mcp",
    version: "1.0.0",
}, {
    capabilities: {
        tools: {},
    },
});
server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
        tools: [
            {
                name: "ios_get_app_info",
                description: "Get detailed information about the app from App Store Connect",
                inputSchema: {
                    type: "object",
                    properties: {},
                    required: [],
                },
            },
            {
                name: "ios_get_app_store_versions",
                description: "Get all App Store versions and their review status",
                inputSchema: {
                    type: "object",
                    properties: {},
                    required: [],
                },
            },
            {
                name: "ios_get_testflight_builds",
                description: "Get TestFlight builds and their status",
                inputSchema: {
                    type: "object",
                    properties: {
                        limit: {
                            type: "number",
                            description: "Number of builds to return (default: 10)",
                        },
                    },
                    required: [],
                },
            },
            {
                name: "ios_get_review_status",
                description: "Check the current review status for App Store and TestFlight",
                inputSchema: {
                    type: "object",
                    properties: {},
                    required: [],
                },
            },
            {
                name: "ios_list_apps",
                description: "List all apps in your App Store Connect account",
                inputSchema: {
                    type: "object",
                    properties: {},
                    required: [],
                },
            },
            {
                name: "ios_expire_build",
                description: "Expire a TestFlight build so it's no longer available for testing",
                inputSchema: {
                    type: "object",
                    properties: {
                        buildId: {
                            type: "string",
                            description: "The build ID to expire (get from ios_get_testflight_builds)",
                        },
                    },
                    required: ["buildId"],
                },
            },
            {
                name: "ios_expire_old_builds",
                description: "Expire all TestFlight builds except the latest one",
                inputSchema: {
                    type: "object",
                    properties: {
                        keepCount: {
                            type: "number",
                            description: "Number of recent builds to keep (default: 1)",
                        },
                    },
                    required: [],
                },
            },
        ],
    };
});
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    try {
        switch (name) {
            case "ios_get_app_info": {
                const response = await apiRequest(`/apps/${APP_ID}`);
                const app = response.data;
                const result = {
                    appId: app.id,
                    name: app.attributes.name,
                    bundleId: app.attributes.bundleId,
                    sku: app.attributes.sku,
                    primaryLocale: app.attributes.primaryLocale,
                };
                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify(result, null, 2),
                        },
                    ],
                };
            }
            case "ios_get_app_store_versions": {
                const response = await apiRequest(`/apps/${APP_ID}/appStoreVersions?limit=10`);
                const versions = response.data.map((version) => ({
                    versionId: version.id,
                    versionString: version.attributes.versionString,
                    platform: version.attributes.platform,
                    appStoreState: version.attributes.appStoreState,
                    appStoreStateDescription: getAppStoreStateDescription(version.attributes.appStoreState),
                    releaseType: version.attributes.releaseType,
                    createdDate: version.attributes.createdDate,
                }));
                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                appId: APP_ID,
                                bundleId: BUNDLE_ID,
                                totalVersions: versions.length,
                                versions,
                            }, null, 2),
                        },
                    ],
                };
            }
            case "ios_get_testflight_builds": {
                const limit = args.limit || 10;
                const response = await apiRequest(`/builds?filter[app]=${APP_ID}&limit=${limit}&sort=-uploadedDate`);
                const builds = response.data.map((build) => ({
                    buildId: build.id,
                    version: build.attributes.version,
                    uploadedDate: build.attributes.uploadedDate,
                    expirationDate: build.attributes.expirationDate,
                    expired: build.attributes.expired,
                    minOsVersion: build.attributes.minOsVersion,
                    processingState: build.attributes.processingState,
                    processingStateDescription: getProcessingStateDescription(build.attributes.processingState),
                }));
                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                appId: APP_ID,
                                bundleId: BUNDLE_ID,
                                totalBuilds: builds.length,
                                builds,
                            }, null, 2),
                        },
                    ],
                };
            }
            case "ios_get_review_status": {
                // Get App Store versions
                const versionsResponse = await apiRequest(`/apps/${APP_ID}/appStoreVersions?limit=5`);
                // Get recent builds
                const buildsResponse = await apiRequest(`/builds?filter[app]=${APP_ID}&limit=5&sort=-uploadedDate`);
                // Get beta review submissions
                let betaReviews = [];
                try {
                    const betaResponse = await apiRequest(`/betaAppReviewSubmissions?filter[app]=${APP_ID}&limit=5`);
                    betaReviews = betaResponse.data.map((submission) => ({
                        buildId: submission.relationships?.build?.data?.id || "unknown",
                        betaReviewState: submission.attributes.betaReviewState,
                        betaReviewStateDescription: getBetaReviewStateDescription(submission.attributes.betaReviewState),
                        submittedDate: submission.attributes.submittedDate,
                    }));
                }
                catch {
                    // Beta reviews might not exist
                }
                const appStoreVersions = versionsResponse.data.map((v) => ({
                    versionString: v.attributes.versionString,
                    platform: v.attributes.platform,
                    state: v.attributes.appStoreState,
                    stateDescription: getAppStoreStateDescription(v.attributes.appStoreState),
                }));
                const pendingVersions = appStoreVersions.filter((v) => ["IN_REVIEW", "WAITING_FOR_REVIEW", "READY_FOR_REVIEW", "PREPARE_FOR_SUBMISSION"].includes(v.state));
                const liveVersions = appStoreVersions.filter((v) => v.state === "READY_FOR_SALE");
                const latestBuild = buildsResponse.data[0];
                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                appId: APP_ID,
                                bundleId: BUNDLE_ID,
                                appStoreStatus: {
                                    hasPendingReview: pendingVersions.length > 0,
                                    pendingVersions,
                                    liveVersions,
                                    allVersions: appStoreVersions,
                                },
                                testFlightStatus: {
                                    latestBuild: latestBuild ? {
                                        version: latestBuild.attributes.version,
                                        uploadedDate: latestBuild.attributes.uploadedDate,
                                        processingState: latestBuild.attributes.processingState,
                                        processingStateDescription: getProcessingStateDescription(latestBuild.attributes.processingState),
                                        expired: latestBuild.attributes.expired,
                                    } : null,
                                    betaReviews,
                                },
                                summary: pendingVersions.length > 0
                                    ? `App Store: ${pendingVersions[0].stateDescription}`
                                    : liveVersions.length > 0
                                        ? `App Store: Live (${liveVersions[0].versionString})`
                                        : "No active App Store version",
                            }, null, 2),
                        },
                    ],
                };
            }
            case "ios_list_apps": {
                const response = await apiRequest("/apps?limit=50");
                const apps = response.data.map((app) => ({
                    appId: app.id,
                    name: app.attributes.name,
                    bundleId: app.attributes.bundleId,
                    sku: app.attributes.sku,
                    primaryLocale: app.attributes.primaryLocale,
                }));
                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                totalApps: apps.length,
                                apps,
                            }, null, 2),
                        },
                    ],
                };
            }
            case "ios_expire_build": {
                const { buildId } = args;
                if (!buildId) {
                    return {
                        content: [{ type: "text", text: JSON.stringify({ success: false, error: "buildId is required" }, null, 2) }],
                        isError: true,
                    };
                }
                // PATCH /v1/builds/{id} with expired: true
                await apiPatchRequest(`/builds/${buildId}`, {
                    data: {
                        type: "builds",
                        id: buildId,
                        attributes: {
                            expired: true,
                        },
                    },
                });
                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                success: true,
                                message: `Build ${buildId} has been expired`,
                            }, null, 2),
                        },
                    ],
                };
            }
            case "ios_expire_old_builds": {
                const { keepCount = 1 } = args;
                // Get all builds
                const buildsResponse = await apiRequest(`/builds?filter[app]=${APP_ID}&sort=-uploadedDate&limit=50`);
                const allBuilds = buildsResponse.data;
                const buildsToExpire = allBuilds
                    .filter((b) => !b.attributes.expired)
                    .slice(keepCount); // Skip the first 'keepCount' builds
                const expiredBuilds = [];
                const failedBuilds = [];
                for (const build of buildsToExpire) {
                    try {
                        await apiPatchRequest(`/builds/${build.id}`, {
                            data: {
                                type: "builds",
                                id: build.id,
                                attributes: {
                                    expired: true,
                                },
                            },
                        });
                        expiredBuilds.push(build.attributes.version);
                    }
                    catch (e) {
                        failedBuilds.push(build.attributes.version);
                    }
                }
                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                success: true,
                                message: `Expired ${expiredBuilds.length} builds, kept ${keepCount} latest`,
                                expiredBuilds,
                                failedBuilds: failedBuilds.length > 0 ? failedBuilds : undefined,
                                keptBuilds: allBuilds.slice(0, keepCount).map((b) => b.attributes.version),
                            }, null, 2),
                        },
                    ],
                };
            }
            default:
                return {
                    content: [
                        {
                            type: "text",
                            text: `Unknown tool: ${name}`,
                        },
                    ],
                    isError: true,
                };
        }
    }
    catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        return {
            content: [
                {
                    type: "text",
                    text: `Error: ${errorMessage}`,
                },
            ],
            isError: true,
        };
    }
});
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("App Store Connect MCP Server running on stdio");
}
main().catch(console.error);
