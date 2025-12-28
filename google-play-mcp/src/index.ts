#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { google } from "googleapis";

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || "com.gavra013.gavra_android";

// Fallback credentials for VS Code MCP (env vars don't work properly)
const FALLBACK_SERVICE_ACCOUNT = {
    type: "service_account",
    project_id: "gavra-notif-20250920162521",
    private_key_id: "f34bd23716033e3f6e5f9ebd5c14066183acc197",
    private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCwtN+HZLoLWRXx\n4JpuRl9D0PSrj7akG6OKWebXsUlLHrMdq2gcL0riAN0Ux1usevDyg50fhvu0Fkg9\npKoKgjWUgIyaO3yGyEs+d6xboHSVJYGkOED+HuSw1XpAqpONACnw3va+YCYYv58W\nBUElL5Pkoct51lqoVaQxrfeKEkOLQOCGFVac8bj3u1Bv9It0c5ruZYkLJIAKXPgA\naCw7o6Pxlj/r2o0d5Ba7s566qWrY6nJUGkEjwkY8EyFSkWEgmJCAeh9aMpMO8Q6Q\nkYW72kdLk7sjgKRpYmhkXvkW6jM2SxhiCr/DR6PucdkdJB2c5hWqE9bNYLzFaSWE\nPJhASsE/AgMBAAECggEAUgglnN0N4SbCIT97caYJo5nle5+D0jtieF+z4n3S4KSn\n0iY4dp0dzj1IZNUHodKQ+IRQ9MndH4UYlEVVCvvXk9D5dMAY1xk0lRNJWF/svzBi\nNrJGubHtyInR7yNAzDw/PCrFsStBhEuwtrBJxdGIfqL9qtnvzCW1y7pPKDHCWWpE\n4cIUOcom154dErEFysNFPggP8WPwPO+BuqzDLbPA+OoUBC/fXzCe/ZwNQjY4SjWB\nEaukzujTNVwvB1r1bKFcCsYlFwE4u0yMzas+DQDk4OSA1g1+Ji/0sIgNjQwHbUzr\nbuwSMkKHmvPF68xvmwhOOzgRvRtdsfqxw1vF7w/IwQKBgQD5AkFKbCWlxya3JCIE\nVg6JfuYyuwD+hFoxMUEirMZWB1svpW1B5gN5L8R4ecmI+GwhhJ5knXr4+O7JxbDb\nMscRzXKkjNkrYsT3P4De+RaZ9o17HhzpvHp1lmrL0ZY9j5AE2L/5BGQ4tflZkxRA\nAjbI81/bbhgxhwJwcEOuv5Fi8wKBgQC1qvJ9uAwWIwImC6/bOyElnoGTWxQTuZOV\nPy2Ehbf0nZmq2HfmUhAnwoBTCF4lDdCulm2ad300GgR3BimWW3wzZ/RLxdL6hDW3\nX6wNE/SZdYasT1DYdxHclhwLKpcrfgkn5ocmFACeMw6amojNc/quoLSLyYf/p3oh\nRSIZI2CDhQKBgQD3YfMlkd2xHfJrnj0hW7Gjjev62Gg7c5f7KTjRzx5YF4TTCCFM\nh8xJmFgzbKL5LfyXLB8ETKQAN6db08hJbN/y4s4Thk622LBgBrnsS0DWAuk6OId2\n+yYaLi65gOYnELp+5iuKpH9BDCDGieVjVg/BgnBoGq90fPHCbPYA5Rb2WwKBgB7C\nCrxuZN16n+qBIA0mPb54z8d7LDMKwIoMYFCHs1WfOV1LuUEts76Hl+J3EDmF1Uc6\nAOSeRnyDyy27xV7Hroelmh8aJ1Zy/AVIFYFBV7CDzYFvDGkZ/9QxNh5N37plZHd0\n+Hzh9hjS3C4g6/idIlxeqTLhtDz8xhjL87H942FhAoGBAPQgTuPsnl1tufQdCq9F\n4FNeI6fkCc5NPBzYLffqF9h8Uo5mQtCoFxbOm01Ne80DMW6zqm6BWs9GgEEJKemB\npBBPtsYm8rdFY4yqFJeZ4GTLve/1UqtRf+zxmCIyyZTj81AzDmwwmZEnrGjFnU09\nXPck5T38KsfIwrua2HD3e2Dg\n-----END PRIVATE KEY-----\n",
    client_email: "gavra-play-store@gavra-notif-20250920162521.iam.gserviceaccount.com",
    client_id: "114763935157287009259",
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    token_uri: "https://oauth2.googleapis.com/token",
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
    client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/gavra-play-store%40gavra-notif-20250920162521.iam.gserviceaccount.com",
    universe_domain: "googleapis.com"
};

const SERVICE_ACCOUNT_KEY = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;

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
    let credentials;

    if (SERVICE_ACCOUNT_KEY) {
        credentials = JSON.parse(SERVICE_ACCOUNT_KEY);
    } else {
        // Use fallback credentials
        credentials = FALLBACK_SERVICE_ACCOUNT;
    }

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
    console.error("Google Play MCP Server running on stdio");
}

main().catch(console.error);
