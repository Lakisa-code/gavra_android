#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import jwt from "jsonwebtoken";
import fetch from "node-fetch";

const ISSUER_ID = process.env.APP_STORE_ISSUER_ID;
const KEY_ID = process.env.APP_STORE_KEY_ID;
const PRIVATE_KEY = process.env.APP_STORE_PRIVATE_KEY;
const APP_ID = process.env.APP_STORE_APP_ID || "6740227083"; // Gavra app ID
const BUNDLE_ID = process.env.APP_STORE_BUNDLE_ID || "com.gavra013.gavraAndroid";

const BASE_URL = "https://api.appstoreconnect.apple.com/v1";

interface AppStoreResponse<T> {
    data: T;
    included?: unknown[];
    links?: { self: string };
    meta?: { paging?: { total: number } };
}

interface AppAttributes {
    name: string;
    bundleId: string;
    sku: string;
    primaryLocale: string;
    availableInNewTerritories?: boolean;
    contentRightsDeclaration?: string;
}

interface AppVersionAttributes {
    versionString: string;
    platform: string;
    appStoreState: string;
    releaseType?: string;
    createdDate?: string;
}

interface BuildAttributes {
    version: string;
    uploadedDate: string;
    expirationDate: string;
    expired: boolean;
    minOsVersion: string;
    processingState: string;
    usesNonExemptEncryption?: boolean;
}

interface BetaAppReviewSubmissionAttributes {
    betaReviewState: string;
    submittedDate?: string;
}

function generateToken(): string {
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

async function apiRequest<T>(endpoint: string): Promise<T> {
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

    return response.json() as Promise<T>;
}

async function apiPatchRequest<T>(endpoint: string, body: object): Promise<T> {
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

    return response.json() as Promise<T>;
}

// Status descriptions for App Store
function getAppStoreStateDescription(state: string): string {
    const stateMap: Record<string, string> = {
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

function getBetaReviewStateDescription(state: string): string {
    const stateMap: Record<string, string> = {
        WAITING_FOR_REVIEW: "Waiting for Beta Review",
        IN_REVIEW: "In Beta Review",
        REJECTED: "Beta Rejected",
        APPROVED: "Beta Approved",
    };
    return stateMap[state] || state;
}

function getProcessingStateDescription(state: string): string {
    const stateMap: Record<string, string> = {
        PROCESSING: "Processing",
        FAILED: "Processing Failed",
        INVALID: "Invalid",
        VALID: "Valid - Ready for Testing",
    };
    return stateMap[state] || state;
}

const server = new Server(
    {
        name: "appstore-mcp",
        version: "1.0.0",
    },
    {
        capabilities: {
            tools: {},
        },
    }
);

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
            {
                name: "ios_reject_submission",
                description: "Cancel/reject the current App Store submission (Developer Reject). Use this to change the build before resubmitting.",
                inputSchema: {
                    type: "object",
                    properties: {
                        versionId: {
                            type: "string",
                            description: "The App Store version ID to reject (get from ios_get_app_store_versions)",
                        },
                    },
                    required: ["versionId"],
                },
            },
            {
                name: "ios_set_build_for_version",
                description: "Set/change the build for an App Store version. The version must be in PREPARE_FOR_SUBMISSION state.",
                inputSchema: {
                    type: "object",
                    properties: {
                        versionId: {
                            type: "string",
                            description: "The App Store version ID",
                        },
                        buildId: {
                            type: "string",
                            description: "The build ID to attach to this version",
                        },
                    },
                    required: ["versionId", "buildId"],
                },
            },
            {
                name: "ios_submit_for_review",
                description: "Submit an App Store version for review. The version must have a build attached.",
                inputSchema: {
                    type: "object",
                    properties: {
                        versionId: {
                            type: "string",
                            description: "The App Store version ID to submit",
                        },
                    },
                    required: ["versionId"],
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
                const response = await apiRequest<AppStoreResponse<{ id: string; attributes: AppAttributes }>>(`/apps/${APP_ID}`);

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
                const response = await apiRequest<AppStoreResponse<{ id: string; attributes: AppVersionAttributes }[]>>(
                    `/apps/${APP_ID}/appStoreVersions?limit=10`
                );

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
                const limit = (args as { limit?: number }).limit || 10;

                const response = await apiRequest<AppStoreResponse<{ id: string; attributes: BuildAttributes }[]>>(
                    `/builds?filter[app]=${APP_ID}&limit=${limit}&sort=-uploadedDate`
                );

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
                const versionsResponse = await apiRequest<AppStoreResponse<{ id: string; attributes: AppVersionAttributes }[]>>(
                    `/apps/${APP_ID}/appStoreVersions?limit=5`
                );

                // Get recent builds
                const buildsResponse = await apiRequest<AppStoreResponse<{ id: string; attributes: BuildAttributes }[]>>(
                    `/builds?filter[app]=${APP_ID}&limit=5&sort=-uploadedDate`
                );

                // Get beta review submissions
                let betaReviews: { buildId: string; betaReviewState: string; betaReviewStateDescription: string; submittedDate?: string }[] = [];
                try {
                    const betaResponse = await apiRequest<AppStoreResponse<{ id: string; attributes: BetaAppReviewSubmissionAttributes; relationships?: { build?: { data?: { id: string } } } }[]>>(
                        `/betaAppReviewSubmissions?filter[app]=${APP_ID}&limit=5`
                    );
                    betaReviews = betaResponse.data.map((submission) => ({
                        buildId: submission.relationships?.build?.data?.id || "unknown",
                        betaReviewState: submission.attributes.betaReviewState,
                        betaReviewStateDescription: getBetaReviewStateDescription(submission.attributes.betaReviewState),
                        submittedDate: submission.attributes.submittedDate,
                    }));
                } catch {
                    // Beta reviews might not exist
                }

                const appStoreVersions = versionsResponse.data.map((v) => ({
                    versionString: v.attributes.versionString,
                    platform: v.attributes.platform,
                    state: v.attributes.appStoreState,
                    stateDescription: getAppStoreStateDescription(v.attributes.appStoreState),
                }));

                const pendingVersions = appStoreVersions.filter((v) =>
                    ["IN_REVIEW", "WAITING_FOR_REVIEW", "READY_FOR_REVIEW", "PREPARE_FOR_SUBMISSION"].includes(v.state)
                );

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
                const response = await apiRequest<AppStoreResponse<{ id: string; attributes: AppAttributes }[]>>("/apps?limit=50");

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
                const { buildId } = args as { buildId: string };

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
                const { keepCount = 1 } = args as { keepCount?: number };

                // Get all builds
                const buildsResponse = await apiRequest<AppStoreResponse<{ id: string; attributes: BuildAttributes }[]>>(
                    `/builds?filter[app]=${APP_ID}&sort=-uploadedDate&limit=50`
                );

                const allBuilds = buildsResponse.data;
                const buildsToExpire = allBuilds
                    .filter((b) => !b.attributes.expired)
                    .slice(keepCount); // Skip the first 'keepCount' builds

                const expiredBuilds: string[] = [];
                const failedBuilds: string[] = [];

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
                    } catch (e) {
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

            case "ios_reject_submission": {
                const { versionId } = args as { versionId: string };

                if (!versionId) {
                    return {
                        content: [{ type: "text", text: JSON.stringify({ success: false, error: "versionId is required" }, null, 2) }],
                        isError: true,
                    };
                }

                const token = generateToken();

                // First, find the reviewSubmission for this app that's in WAITING_FOR_REVIEW state
                const reviewSubmissionsResponse = await fetch(
                    `${BASE_URL}/reviewSubmissions?filter[app]=${APP_ID}&filter[state]=WAITING_FOR_REVIEW`,
                    {
                        headers: {
                            Authorization: `Bearer ${token}`,
                            "Content-Type": "application/json",
                        },
                    }
                );

                if (!reviewSubmissionsResponse.ok) {
                    const errorText = await reviewSubmissionsResponse.text();
                    throw new Error(`Failed to get review submissions: ${reviewSubmissionsResponse.status} - ${errorText}`);
                }

                const reviewSubmissions = await reviewSubmissionsResponse.json() as { data: { id: string; attributes: { state: string } }[] };

                if (!reviewSubmissions.data || reviewSubmissions.data.length === 0) {
                    throw new Error("No pending review submission found. The app might not be in review.");
                }

                const submissionId = reviewSubmissions.data[0].id;

                // PATCH the reviewSubmission to CANCELING state
                const cancelResponse = await fetch(`${BASE_URL}/reviewSubmissions/${submissionId}`, {
                    method: "PATCH",
                    headers: {
                        Authorization: `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        data: {
                            type: "reviewSubmissions",
                            id: submissionId,
                            attributes: {
                                canceled: true,
                            },
                        },
                    }),
                });

                if (!cancelResponse.ok) {
                    const errorText = await cancelResponse.text();
                    throw new Error(`Failed to cancel submission: ${cancelResponse.status} - ${errorText}`);
                }

                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                success: true,
                                message: `Review submission ${submissionId} has been cancelled. Version is now back to PREPARE_FOR_SUBMISSION state. You can now change the build.`,
                                submissionId: submissionId,
                            }, null, 2),
                        },
                    ],
                };
            }

            case "ios_set_build_for_version": {
                const { versionId, buildId } = args as { versionId: string; buildId: string };

                if (!versionId || !buildId) {
                    return {
                        content: [{ type: "text", text: JSON.stringify({ success: false, error: "versionId and buildId are required" }, null, 2) }],
                        isError: true,
                    };
                }

                // PATCH /v1/appStoreVersions/{id}/relationships/build
                const token = generateToken();
                const response = await fetch(`${BASE_URL}/appStoreVersions/${versionId}/relationships/build`, {
                    method: "PATCH",
                    headers: {
                        Authorization: `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        data: {
                            type: "builds",
                            id: buildId,
                        },
                    }),
                });

                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error(`Failed to set build: ${response.status} - ${errorText}`);
                }

                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                success: true,
                                message: `Build ${buildId} has been set for version ${versionId}`,
                            }, null, 2),
                        },
                    ],
                };
            }

            case "ios_submit_for_review": {
                const { versionId } = args as { versionId: string };

                if (!versionId) {
                    return {
                        content: [{ type: "text", text: JSON.stringify({ success: false, error: "versionId is required" }, null, 2) }],
                        isError: true,
                    };
                }

                // POST /v1/appStoreVersionSubmissions
                const token = generateToken();
                const response = await fetch(`${BASE_URL}/appStoreVersionSubmissions`, {
                    method: "POST",
                    headers: {
                        Authorization: `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        data: {
                            type: "appStoreVersionSubmissions",
                            relationships: {
                                appStoreVersion: {
                                    data: {
                                        type: "appStoreVersions",
                                        id: versionId,
                                    },
                                },
                            },
                        },
                    }),
                });

                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error(`Failed to submit for review: ${response.status} - ${errorText}`);
                }

                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                success: true,
                                message: `Version ${versionId} has been submitted for App Store review!`,
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
    } catch (error) {
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
