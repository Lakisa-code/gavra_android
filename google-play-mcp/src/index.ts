#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { google } from "googleapis";
import { Logger } from "./logger.js";

const logger = new Logger('google-play-mcp');

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME;
const SERVICE_ACCOUNT_KEY = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;

// Validate required environment variables
if (!PACKAGE_NAME) {
    logger.error('Missing required environment variable: GOOGLE_PLAY_PACKAGE_NAME');
    process.exit(1);
}

if (!SERVICE_ACCOUNT_KEY) {
    logger.error('Missing required environment variable: GOOGLE_PLAY_SERVICE_ACCOUNT_KEY');
    logger.error('Please set the service account JSON in your mcp.json');
    process.exit(1);
}

logger.info('Google Play credentials loaded successfully');

interface TrackRelease {
    name?: string | null;
    versionCodes?: (string | null)[] | null;
    status?: string | null;
    userFraction?: number | null;
    releaseNotes?: { language?: string | null; text?: string | null }[] | null;
}

interface Track {
    track?: string | null;
    releases?: TrackRelease[] | null;
}

async function getAndroidPublisher() {
    const credentials = JSON.parse(SERVICE_ACCOUNT_KEY!);

    const auth = new google.auth.GoogleAuth({
        credentials,
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });

    return google.androidpublisher({ version: "v3", auth });
}

// Status mapping for releases
function getStatusDescription(status: string | null | undefined): string {
    const statusMap: Record<string, string> = {
        draft: "Draft - Not yet published",
        completed: "Published - Live on Google Play",
        halted: "Halted - Rollout paused",
        inProgress: "In Progress - Rolling out",
        statusUnspecified: "Status unknown",
    };
    return status ? statusMap[status] || status : "Unknown";
}

// Track descriptions
function getTrackDescription(track: string | null | undefined): string {
    const trackMap: Record<string, string> = {
        production: "Production (Live)",
        beta: "Closed Testing (Beta)",
        alpha: "Internal Testing (Alpha)",
        internal: "Internal Testing",
    };
    return track ? trackMap[track] || track : "Unknown";
}

const server = new Server(
    {
        name: "google-play-mcp",
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
                name: "google_get_app_info",
                description: "Get detailed information about the app from Google Play Console, including all tracks and their release statuses",
                inputSchema: {
                    type: "object",
                    properties: {},
                    required: [],
                },
            },
            {
                name: "google_get_track_status",
                description: "Get the status of a specific track (production, beta, alpha, internal)",
                inputSchema: {
                    type: "object",
                    properties: {
                        track: {
                            type: "string",
                            description: "Track name: production, beta, alpha, or internal",
                            enum: ["production", "beta", "alpha", "internal"],
                        },
                    },
                    required: ["track"],
                },
            },
            {
                name: "google_list_releases",
                description: "List all releases across all tracks",
                inputSchema: {
                    type: "object",
                    properties: {},
                    required: [],
                },
            },
            {
                name: "google_get_review_status",
                description: "Check if there are any pending reviews or app updates in progress",
                inputSchema: {
                    type: "object",
                    properties: {},
                    required: [],
                },
            },
        ],
    };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    try {
        const androidPublisher = await getAndroidPublisher();

        switch (name) {
            case "google_get_app_info": {
                // Get app details from all tracks
                const tracksResponse = await androidPublisher.edits.insert({
                    packageName: PACKAGE_NAME,
                });

                const editId = tracksResponse.data.id!;

                const tracks = ["production", "beta", "alpha", "internal"];
                const trackDetails: Record<string, Track | null> = {};

                for (const track of tracks) {
                    try {
                        const trackResponse = await androidPublisher.edits.tracks.get({
                            packageName: PACKAGE_NAME,
                            editId,
                            track,
                        });
                        trackDetails[track] = trackResponse.data;
                    } catch {
                        trackDetails[track] = null;
                    }
                }

                // Delete the edit (we're just reading)
                await androidPublisher.edits.delete({
                    packageName: PACKAGE_NAME,
                    editId,
                });

                const result = {
                    packageName: PACKAGE_NAME,
                    tracks: Object.entries(trackDetails).map(([trackName, data]) => ({
                        track: trackName,
                        trackDescription: getTrackDescription(trackName),
                        releases: data?.releases?.map((release: TrackRelease) => ({
                            name: release.name,
                            versionCodes: release.versionCodes,
                            status: release.status,
                            statusDescription: getStatusDescription(release.status),
                            userFraction: release.userFraction,
                            releaseNotes: release.releaseNotes,
                        })) || [],
                    })),
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

            case "google_get_track_status": {
                const track = (args as { track: string }).track;

                const editResponse = await androidPublisher.edits.insert({
                    packageName: PACKAGE_NAME,
                });

                const editId = editResponse.data.id!;

                const trackResponse = await androidPublisher.edits.tracks.get({
                    packageName: PACKAGE_NAME,
                    editId,
                    track,
                });

                await androidPublisher.edits.delete({
                    packageName: PACKAGE_NAME,
                    editId,
                });

                const trackData = trackResponse.data;
                const latestRelease = trackData.releases?.[0];

                const result = {
                    track,
                    trackDescription: getTrackDescription(track),
                    latestRelease: latestRelease ? {
                        name: latestRelease.name,
                        versionCodes: latestRelease.versionCodes,
                        status: latestRelease.status,
                        statusDescription: getStatusDescription(latestRelease.status),
                        userFraction: latestRelease.userFraction,
                        releaseNotes: latestRelease.releaseNotes,
                    } : null,
                    allReleases: trackData.releases?.map((release: TrackRelease) => ({
                        name: release.name,
                        versionCodes: release.versionCodes,
                        status: release.status,
                        statusDescription: getStatusDescription(release.status),
                    })) || [],
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

            case "google_list_releases": {
                const editResponse = await androidPublisher.edits.insert({
                    packageName: PACKAGE_NAME,
                });

                const editId = editResponse.data.id!;

                const tracksResponse = await androidPublisher.edits.tracks.list({
                    packageName: PACKAGE_NAME,
                    editId,
                });

                await androidPublisher.edits.delete({
                    packageName: PACKAGE_NAME,
                    editId,
                });

                const allReleases = tracksResponse.data.tracks?.flatMap((track: Track) =>
                    track.releases?.map((release: TrackRelease) => ({
                        track: track.track,
                        trackDescription: getTrackDescription(track.track),
                        name: release.name,
                        versionCodes: release.versionCodes,
                        status: release.status,
                        statusDescription: getStatusDescription(release.status),
                        userFraction: release.userFraction,
                    })) || []
                ) || [];

                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                packageName: PACKAGE_NAME,
                                totalReleases: allReleases.length,
                                releases: allReleases,
                            }, null, 2),
                        },
                    ],
                };
            }

            case "google_get_review_status": {
                // Check for any in-progress or pending releases
                const editResponse = await androidPublisher.edits.insert({
                    packageName: PACKAGE_NAME,
                });

                const editId = editResponse.data.id!;

                const tracksResponse = await androidPublisher.edits.tracks.list({
                    packageName: PACKAGE_NAME,
                    editId,
                });

                await androidPublisher.edits.delete({
                    packageName: PACKAGE_NAME,
                    editId,
                });

                const pendingReleases = tracksResponse.data.tracks?.flatMap((track: Track) =>
                    track.releases?.filter((release: TrackRelease) =>
                        release.status === "inProgress" || release.status === "draft"
                    ).map((release: TrackRelease) => ({
                        track: track.track,
                        trackDescription: getTrackDescription(track.track),
                        name: release.name,
                        versionCodes: release.versionCodes,
                        status: release.status,
                        statusDescription: getStatusDescription(release.status),
                    })) || []
                ) || [];

                const liveReleases = tracksResponse.data.tracks?.flatMap((track: Track) =>
                    track.releases?.filter((release: TrackRelease) =>
                        release.status === "completed"
                    ).map((release: TrackRelease) => ({
                        track: track.track,
                        trackDescription: getTrackDescription(track.track),
                        name: release.name,
                        versionCodes: release.versionCodes,
                    })) || []
                ) || [];

                return {
                    content: [
                        {
                            type: "text",
                            text: JSON.stringify({
                                packageName: PACKAGE_NAME,
                                hasPendingReleases: pendingReleases.length > 0,
                                pendingReleases,
                                liveReleases,
                                summary: pendingReleases.length > 0
                                    ? `${pendingReleases.length} release(s) pending or in progress`
                                    : "No pending releases - all releases are live or completed",
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
                            text: JSON.stringify({
                                success: false,
                                error: `Unknown tool: ${name}`,
                            }, null, 2),
                        },
                    ],
                    isError: true,
                };
        }
    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        const errorContext = {
            tool: name,
            packageName: PACKAGE_NAME,
            timestamp: new Date().toISOString(),
        };

        logger.exception(`Tool execution failed: ${name}`, error as Error, errorContext);

        return {
            content: [
                {
                    type: "text",
                    text: JSON.stringify({
                        success: false,
                        error: errorMessage,
                        tool: name,
                        packageName: PACKAGE_NAME,
                        hint: getGooglePlayErrorHint(errorMessage),
                    }, null, 2),
                },
            ],
            isError: true,
        };
    }
});

/**
 * Get helpful hints based on common Google Play API error messages
 */
function getGooglePlayErrorHint(errorMessage: string): string | undefined {
    if (errorMessage.includes('401') || errorMessage.includes('Unauthorized')) {
        return 'Check your GOOGLE_PLAY_SERVICE_ACCOUNT_KEY environment variable';
    }
    if (errorMessage.includes('403') || errorMessage.includes('Forbidden')) {
        return 'Service account may not have Android Publisher API access. Check Google Cloud Console permissions';
    }
    if (errorMessage.includes('404') || errorMessage.includes('applicationNotFound')) {
        return 'Package name not found. Verify GOOGLE_PLAY_PACKAGE_NAME is correct and the app exists in Google Play Console';
    }
    if (errorMessage.includes('Invalid JSON')) {
        return 'GOOGLE_PLAY_SERVICE_ACCOUNT_KEY contains invalid JSON. Ensure it is properly escaped';
    }
    return undefined;
}

async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    logger.info("🚀 Google Play MCP Server started");
}

main().catch((error) => {
    logger.exception('Failed to start server', error);
    process.exit(1);
});
