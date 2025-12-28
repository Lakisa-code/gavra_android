#!/usr/bin/env node
/**
 * 🚀 Huawei AppGallery Connect MCP Server
 *
 * Model Context Protocol server for managing Huawei AppGallery Connect apps.
 *
 * Features:
 * - 📱 List and get app info
 * - 📤 Upload APK/AAB files
 * - 📝 Update app metadata (name, description, screenshots)
 * - 🚀 Submit app for review
 * - 📊 Check compilation/review status
 *
 * Usage:
 * 1. Get credentials from AppGallery Connect Console
 * 2. Set environment variables: HUAWEI_CLIENT_ID, HUAWEI_CLIENT_SECRET
 * 3. Add to mcp.json config
 */
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema, } from '@modelcontextprotocol/sdk/types.js';
import { HuaweiAppGalleryClient } from './huawei-client.js';
// Environment variables for credentials - with hardcoded fallback for debugging
const HUAWEI_CLIENT_ID = process.env.HUAWEI_CLIENT_ID || '1850740994484473152';
const HUAWEI_CLIENT_SECRET = process.env.HUAWEI_CLIENT_SECRET || 'F4CC48ADE493A712D729DDF8B7A11542591BDBC52AD2999E950CC7BED1DEDC98';
console.error('[MCP DEBUG] HUAWEI_CLIENT_ID:', HUAWEI_CLIENT_ID);
console.error('[MCP DEBUG] HUAWEI_CLIENT_SECRET set:', !!HUAWEI_CLIENT_SECRET);
// Initialize Huawei client
const huaweiClient = new HuaweiAppGalleryClient({
    clientId: HUAWEI_CLIENT_ID,
    clientSecret: HUAWEI_CLIENT_SECRET,
});
// Define available tools
const TOOLS = [
    {
        name: 'huawei_list_apps',
        description: 'List all apps in your AppGallery Connect account',
        inputSchema: {
            type: 'object',
            properties: {},
            required: [],
        },
    },
    {
        name: 'huawei_get_app_info',
        description: 'Get detailed information about a specific app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID from AppGallery Connect',
                },
            },
            required: ['appId'],
        },
    },
    {
        name: 'huawei_upload_apk',
        description: 'Upload an APK or AAB file to AppGallery Connect',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID from AppGallery Connect',
                },
                filePath: {
                    type: 'string',
                    description: 'Absolute path to the APK or AAB file',
                },
                fileType: {
                    type: 'string',
                    enum: ['apk', 'aab'],
                    description: 'File type (apk or aab)',
                    default: 'apk',
                },
            },
            required: ['appId', 'filePath'],
        },
    },
    {
        name: 'huawei_update_app_info',
        description: 'Update app metadata (name, description, new features)',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID from AppGallery Connect',
                },
                language: {
                    type: 'string',
                    description: 'Language code (e.g., en-US, sr-Latn-RS)',
                    default: 'en-US',
                },
                appName: {
                    type: 'string',
                    description: 'App name (max 64 characters)',
                },
                appDesc: {
                    type: 'string',
                    description: 'App description (max 8000 characters)',
                },
                briefInfo: {
                    type: 'string',
                    description: 'Brief description (max 170 characters)',
                },
                newFeatures: {
                    type: 'string',
                    description: "What's new in this version (max 500 characters)",
                },
            },
            required: ['appId'],
        },
    },
    {
        name: 'huawei_submit_for_review',
        description: 'Submit the app for review and publishing',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID from AppGallery Connect',
                },
                releaseTime: {
                    type: 'string',
                    description: 'Scheduled release time (ISO 8601 format, optional)',
                },
            },
            required: ['appId'],
        },
    },
    {
        name: 'huawei_get_status',
        description: 'Get the compilation and review status of an app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID from AppGallery Connect',
                },
            },
            required: ['appId'],
        },
    },
];
// Create MCP Server
const server = new Server({
    name: 'huawei-appgallery-mcp',
    version: '1.0.0',
}, {
    capabilities: {
        tools: {},
    },
});
// Handle list tools request
server.setRequestHandler(ListToolsRequestSchema, async () => {
    return { tools: TOOLS };
});
// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    try {
        switch (name) {
            case 'huawei_list_apps': {
                const apps = await huaweiClient.listApps();
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                count: apps.length,
                                apps: apps.map((app) => ({
                                    appId: app.appId,
                                    appName: app.appName,
                                    packageName: app.packageName,
                                    versionName: app.versionName,
                                    releaseState: app.releaseState,
                                })),
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_get_app_info': {
                const { appId } = args;
                const appInfo = await huaweiClient.getAppInfo(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({ success: true, appInfo }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_upload_apk': {
                const { appId, filePath, fileType = 'apk' } = args;
                // Get upload URL
                const uploadInfo = await huaweiClient.getUploadUrl(appId, fileType);
                // Upload file
                const fileUrl = await huaweiClient.uploadFile(uploadInfo.uploadUrl, uploadInfo.authCode, filePath);
                // Update app file info
                await huaweiClient.updateAppFileInfo(appId, fileUrl);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: `Successfully uploaded ${fileType.toUpperCase()} to AppGallery Connect`,
                                fileUrl,
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_update_app_info': {
                const { appId, language = 'en-US', appName, appDesc, briefInfo, newFeatures, } = args;
                await huaweiClient.updateLanguageInfo(appId, language, {
                    appName,
                    appDesc,
                    briefInfo,
                    newFeatures,
                });
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: `Successfully updated app info for language: ${language}`,
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_submit_for_review': {
                const { appId, releaseTime } = args;
                const result = await huaweiClient.submitForReview(appId, releaseTime);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: result.ret.code === 0,
                                message: result.ret.msg,
                                result,
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_get_status': {
                const { appId } = args;
                const status = await huaweiClient.getCompilationStatus(appId);
                const appInfo = await huaweiClient.getAppInfo(appId);
                const releaseStateDesc = {
                    1: 'Draft',
                    2: 'Reviewing',
                    3: 'Review Rejected',
                    4: 'Released',
                    5: 'Updating',
                    6: 'Update Rejected',
                    7: 'Removed',
                };
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                appName: appInfo.appName,
                                versionName: appInfo.versionName,
                                releaseState: releaseStateDesc[appInfo.releaseState] || 'Unknown',
                                compilation: status,
                            }, null, 2),
                        },
                    ],
                };
            }
            default:
                throw new Error(`Unknown tool: ${name}`);
        }
    }
    catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        return {
            content: [
                {
                    type: 'text',
                    text: JSON.stringify({
                        success: false,
                        error: errorMessage,
                    }, null, 2),
                },
            ],
            isError: true,
        };
    }
});
// Start server
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error('🚀 Huawei AppGallery MCP Server running');
}
main().catch(console.error);
