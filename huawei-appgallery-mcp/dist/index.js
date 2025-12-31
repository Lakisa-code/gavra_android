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
import { Logger } from './logger.js';
const logger = new Logger('huawei-appgallery-mcp');
// Environment variables for credentials - REQUIRED
const HUAWEI_CLIENT_ID = process.env.HUAWEI_CLIENT_ID;
const HUAWEI_CLIENT_SECRET = process.env.HUAWEI_CLIENT_SECRET;
const HUAWEI_APP_ID = process.env.HUAWEI_APP_ID; // Default App ID
// Validate required environment variables
if (!HUAWEI_CLIENT_ID || !HUAWEI_CLIENT_SECRET) {
    logger.error('Missing required environment variables: HUAWEI_CLIENT_ID and/or HUAWEI_CLIENT_SECRET');
    logger.error('Please set these in your mcp.json or environment');
    process.exit(1);
}
logger.info('Huawei credentials loaded successfully');
logger.info(`Client ID: ${HUAWEI_CLIENT_ID}`);
logger.info(`Client Secret: ${HUAWEI_CLIENT_SECRET?.substring(0, 8)}...`);
if (HUAWEI_APP_ID) {
    logger.info(`Default App ID: ${HUAWEI_APP_ID}`);
}
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
                    description: 'The App ID from AppGallery Connect (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
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
                    description: 'The App ID from AppGallery Connect (optional if HUAWEI_APP_ID env is set)',
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
            required: ['filePath'],
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
                    description: 'The App ID from AppGallery Connect (optional if HUAWEI_APP_ID env is set)',
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
            required: [],
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
                    description: 'The App ID from AppGallery Connect (optional if HUAWEI_APP_ID env is set)',
                },
                releaseTime: {
                    type: 'string',
                    description: 'Scheduled release time (ISO 8601 format, optional)',
                },
            },
            required: [],
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
                    description: 'The App ID from AppGallery Connect (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    {
        name: 'huawei_set_test_account',
        description: 'Set test account credentials for Huawei reviewers. This is REQUIRED when submitting an app that has login functionality.',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID from AppGallery Connect (optional if HUAWEI_APP_ID env is set)',
                },
                account: {
                    type: 'string',
                    description: 'Test account username, email, or phone number for reviewers to use',
                },
                password: {
                    type: 'string',
                    description: 'Test account password or verification code',
                },
                remark: {
                    type: 'string',
                    description: 'Additional instructions for reviewers (e.g., "This is a driver account. Login with phone number.")',
                },
            },
            required: ['account', 'password'],
        },
    },
    {
        name: 'huawei_get_test_account',
        description: 'Get the current test account info configured for reviewers',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID from AppGallery Connect (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
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
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required. Set HUAWEI_APP_ID env or provide appId parameter.' }, null, 2) }],
                    };
                }
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
                const { appId = HUAWEI_APP_ID, filePath, fileType = 'apk' } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required. Set HUAWEI_APP_ID env or provide appId parameter.' }, null, 2) }],
                    };
                }
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
                const { appId = HUAWEI_APP_ID, language = 'en-US', appName, appDesc, briefInfo, newFeatures, } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required. Set HUAWEI_APP_ID env or provide appId parameter.' }, null, 2) }],
                    };
                }
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
                const { appId = HUAWEI_APP_ID, releaseTime } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required. Set HUAWEI_APP_ID env or provide appId parameter.' }, null, 2) }],
                    };
                }
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
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required. Set HUAWEI_APP_ID env or provide appId parameter.' }, null, 2) }],
                    };
                }
                const appInfo = await huaweiClient.getAppInfo(appId);
                // Huawei AppGallery releaseState codes:
                // https://developer.huawei.com/consumer/en/doc/harmonyos-references/appgallerykit-publishingapi-getappinfo-0000001861766669
                const releaseStateDesc = {
                    1: 'Draft',
                    2: 'Released',
                    3: 'Removed',
                    4: 'Reviewing',
                    5: 'Review Rejected',
                    6: 'Updating',
                    7: 'Update Rejected',
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
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_set_test_account': {
                const { appId = HUAWEI_APP_ID, account, password, remark } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required. Set HUAWEI_APP_ID env or provide appId parameter.' }, null, 2) }],
                    };
                }
                if (!account || !password) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'account and password are required' }, null, 2) }],
                    };
                }
                await huaweiClient.setTestAccountInfo(appId, {
                    account,
                    password,
                    accountRemark: remark,
                });
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: 'Test account info set successfully for reviewers',
                                testAccount: {
                                    account,
                                    password: '********',
                                    remark: remark || '',
                                },
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_get_test_account': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required. Set HUAWEI_APP_ID env or provide appId parameter.' }, null, 2) }],
                    };
                }
                const testInfo = await huaweiClient.getTestAccountInfo(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                testAccount: testInfo.testAccount || 'Not set',
                                testPassword: testInfo.testPassword ? '********' : 'Not set',
                                testRemark: testInfo.testRemark || 'Not set',
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
        const errorContext = {
            tool: name,
            arguments: args,
            timestamp: new Date().toISOString(),
        };
        logger.exception(`Tool execution failed: ${name}`, error, errorContext);
        return {
            content: [
                {
                    type: 'text',
                    text: JSON.stringify({
                        success: false,
                        error: errorMessage,
                        tool: name,
                        hint: getErrorHint(errorMessage),
                    }, null, 2),
                },
            ],
            isError: true,
        };
    }
});
/**
 * Get helpful hints based on common error messages
 */
function getErrorHint(errorMessage) {
    if (errorMessage.includes('Authentication failed') || errorMessage.includes('401')) {
        return 'Check your HUAWEI_CLIENT_ID and HUAWEI_CLIENT_SECRET environment variables';
    }
    if (errorMessage.includes('403') || errorMessage.includes('Forbidden')) {
        return 'Your API credentials may not have the required permissions. Check AppGallery Connect Console > Connect API';
    }
    if (errorMessage.includes('404') || errorMessage.includes('not found')) {
        return 'The requested resource was not found. Verify the appId is correct';
    }
    if (errorMessage.includes('ENOENT') || errorMessage.includes('no such file')) {
        return 'File not found. Check the file path is correct and the file exists';
    }
    return undefined;
}
// Start server
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    logger.info('🚀 Huawei AppGallery MCP Server started');
}
main().catch((error) => {
    logger.exception('Failed to start server', error);
    process.exit(1);
});
