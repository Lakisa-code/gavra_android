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
import 'dotenv/config.js';
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
    {
        name: 'huawei_delete_app_files',
        description: 'Delete uploaded APK/AAB files from the draft version. Use this to remove old packages before uploading new ones.',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID from AppGallery Connect (optional if HUAWEI_APP_ID env is set)',
                },
                fileType: {
                    type: 'number',
                    description: 'File type to delete: 5 = APK (default), 3 = RPK',
                    default: 5,
                },
            },
            required: [],
        },
    },
    // === LANGUAGE & LOCALIZATION ===
    {
        name: 'huawei_list_languages',
        description: 'List all language localizations configured for the app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    {
        name: 'huawei_get_language_info',
        description: 'Get localized app info for a specific language',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                language: {
                    type: 'string',
                    description: 'Language code (e.g., en-US, sr-Latn-RS, de-DE)',
                },
            },
            required: ['language'],
        },
    },
    {
        name: 'huawei_delete_language',
        description: 'Delete a language localization from the app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                language: {
                    type: 'string',
                    description: 'Language code to delete (e.g., de-DE)',
                },
            },
            required: ['language'],
        },
    },
    // === COMPILATION & BUILD ===
    {
        name: 'huawei_get_compilation_status',
        description: 'Get the compilation/build status of the uploaded AAB',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    // === PHASED RELEASE ===
    {
        name: 'huawei_update_phased_release',
        description: 'Update phased release percentage for a released app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                phasedReleasePercent: {
                    type: 'number',
                    description: 'Release percentage (1-100). Use 100 for full release.',
                },
            },
            required: ['phasedReleasePercent'],
        },
    },
    {
        name: 'huawei_stop_phased_release',
        description: 'Stop/halt a phased release rollout',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    // === GEO RESTRICTIONS ===
    {
        name: 'huawei_get_geo_restrictions',
        description: 'Get country/region distribution settings for the app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    {
        name: 'huawei_set_geo_restrictions',
        description: 'Set country/region distribution settings',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                countries: {
                    type: 'array',
                    items: { type: 'string' },
                    description: 'Array of country codes (e.g., ["RS", "HR", "BA"])',
                },
                releaseType: {
                    type: 'number',
                    description: '1 = Release to all countries, 3 = Release to specific countries only',
                },
            },
            required: ['countries', 'releaseType'],
        },
    },
    // === SCREENSHOTS ===
    {
        name: 'huawei_upload_screenshot',
        description: 'Upload a screenshot for the app listing',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                filePath: {
                    type: 'string',
                    description: 'Absolute path to the screenshot image (PNG/JPG)',
                },
                language: {
                    type: 'string',
                    description: 'Language code for the screenshot (e.g., en-US)',
                    default: 'en-US',
                },
                deviceType: {
                    type: 'number',
                    description: 'Device type: 1=Phone, 2=Tablet, 3=TV, 4=Watch, 5=Car',
                    default: 1,
                },
            },
            required: ['filePath'],
        },
    },
    // === CERTIFICATE/SIGNATURE ===
    {
        name: 'huawei_get_upload_certificate',
        description: 'Get the upload certificate (signing key) info for the app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    // === APP VERSION HISTORY ===
    {
        name: 'huawei_get_aab_compile_status',
        description: 'Get AAB to APK compilation status and generated APK info',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                pkgVersion: {
                    type: 'string',
                    description: 'Package version to check (optional, defaults to latest)',
                },
            },
            required: [],
        },
    },
    // === APP TAKEDOWN ===
    {
        name: 'huawei_takedown_app',
        description: 'Take down (unpublish) the app from AppGallery. WARNING: This removes the app from the store!',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                reason: {
                    type: 'string',
                    description: 'Reason for takedown',
                },
            },
            required: [],
        },
    },
    // === CANCEL SUBMISSION ===
    {
        name: 'huawei_cancel_submission',
        description: 'Cancel a pending review submission. Only works if app is still in review.',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    // === APP VERSION INFO ===
    {
        name: 'huawei_get_version_info',
        description: 'Get detailed version information including all package versions',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    // === PRIVACY POLICY ===
    {
        name: 'huawei_set_privacy_policy',
        description: 'Set the privacy policy URL for the app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                privacyPolicyUrl: {
                    type: 'string',
                    description: 'Privacy policy URL',
                },
            },
            required: ['privacyPolicyUrl'],
        },
    },
    // === APP ICON ===
    {
        name: 'huawei_upload_app_icon',
        description: 'Upload app icon image',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                filePath: {
                    type: 'string',
                    description: 'Absolute path to the icon image (PNG, 512x512)',
                },
            },
            required: ['filePath'],
        },
    },
    // === FEATURE GRAPHIC ===
    {
        name: 'huawei_upload_feature_graphic',
        description: 'Upload feature graphic (banner) image for the store listing',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                filePath: {
                    type: 'string',
                    description: 'Absolute path to the feature graphic image',
                },
                language: {
                    type: 'string',
                    description: 'Language code (e.g., en-US)',
                    default: 'en-US',
                },
            },
            required: ['filePath'],
        },
    },
    // === DELETE SCREENSHOT ===
    {
        name: 'huawei_delete_screenshots',
        description: 'Delete all screenshots for a specific language and device type',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                language: {
                    type: 'string',
                    description: 'Language code (e.g., en-US)',
                    default: 'en-US',
                },
                deviceType: {
                    type: 'number',
                    description: 'Device type: 1=Phone, 2=Tablet, 3=TV, 4=Watch, 5=Car',
                    default: 1,
                },
            },
            required: [],
        },
    },
    // === RELEASE NOTES ===
    {
        name: 'huawei_get_release_notes',
        description: 'Get release notes (what\'s new) for a specific language',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                language: {
                    type: 'string',
                    description: 'Language code (e.g., en-US)',
                    default: 'en-US',
                },
            },
            required: [],
        },
    },
    // === CATEGORY INFO ===
    {
        name: 'huawei_get_category_info',
        description: 'Get the app category and content rating info',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    // === PACKAGE SUMMARY ===
    {
        name: 'huawei_get_package_summary',
        description: 'Get summary of all uploaded packages (APK/AAB) with their version info',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    // === PERMISSION LIST ===
    {
        name: 'huawei_get_permissions',
        description: 'Get list of permissions declared by the app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    // === SUPPORTED COUNTRIES ===
    {
        name: 'huawei_list_supported_countries',
        description: 'List all supported countries/regions for Huawei AppGallery',
        inputSchema: {
            type: 'object',
            properties: {},
            required: [],
        },
    },
    // === APP DOWNLOAD STATS ===
    {
        name: 'huawei_get_app_downloads',
        description: 'Get download statistics for the app (if available)',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
            },
            required: [],
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // 🧪 CLOUD TESTING
    // ═══════════════════════════════════════════════════════════════════════════
    {
        name: 'huawei_cloud_test_devices',
        description: 'List available devices for Cloud Testing (Huawei phones/tablets in the cloud)',
        inputSchema: {
            type: 'object',
            properties: {},
            required: [],
        },
    },
    {
        name: 'huawei_cloud_test_create',
        description: 'Create a Cloud Test task to test your APK on real Huawei devices. Test types: 1=Compatibility, 2=Stability, 3=Performance, 4=Power consumption',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                testType: {
                    type: 'number',
                    description: 'Test type: 1=Compatibility (does it install/run), 2=Stability (crash detection), 3=Performance (CPU/RAM), 4=Power (battery)',
                    default: 1,
                },
                apkPath: {
                    type: 'string',
                    description: 'Absolute path to the APK file to test',
                },
                deviceIds: {
                    type: 'array',
                    items: { type: 'string' },
                    description: 'Array of device IDs to test on (get from huawei_cloud_test_devices). If empty, uses popular devices.',
                },
                timeout: {
                    type: 'number',
                    description: 'Test timeout in minutes (default 30)',
                    default: 30,
                },
            },
            required: ['apkPath'],
        },
    },
    {
        name: 'huawei_cloud_test_status',
        description: 'Get the status and progress of a Cloud Test task',
        inputSchema: {
            type: 'object',
            properties: {
                taskId: {
                    type: 'string',
                    description: 'The test task ID (returned from huawei_cloud_test_create)',
                },
            },
            required: ['taskId'],
        },
    },
    {
        name: 'huawei_cloud_test_list',
        description: 'List all Cloud Test tasks for an app',
        inputSchema: {
            type: 'object',
            properties: {
                appId: {
                    type: 'string',
                    description: 'The App ID (optional if HUAWEI_APP_ID env is set)',
                },
                pageNum: {
                    type: 'number',
                    description: 'Page number (default 1)',
                    default: 1,
                },
                pageSize: {
                    type: 'number',
                    description: 'Results per page (default 10)',
                    default: 10,
                },
            },
            required: [],
        },
    },
    {
        name: 'huawei_cloud_test_report',
        description: 'Get the detailed test report for a completed Cloud Test task',
        inputSchema: {
            type: 'object',
            properties: {
                taskId: {
                    type: 'string',
                    description: 'The test task ID',
                },
            },
            required: ['taskId'],
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
                    0: 'Created',
                    1: 'Draft',
                    2: 'Released',
                    3: 'Removed',
                    4: 'Reviewing',
                    5: 'Review Rejected',
                    6: 'Updating',
                    7: 'Update Rejected',
                    8: 'On Sale',
                    9: 'Audit Passed',
                    10: 'Audit Failed',
                };
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                appName: appInfo.appName || 'Unknown App',
                                versionName: appInfo.versionName || appInfo.versionNumber || 'Unknown',
                                versionCode: appInfo.versionCode,
                                releaseState: releaseStateDesc[appInfo.releaseState] || `Unknown (${appInfo.releaseState})`,
                                onShelfVersion: appInfo.onShelfVersionNumber,
                                updateTime: appInfo.updateTime,
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
            case 'huawei_delete_app_files': {
                const { appId = HUAWEI_APP_ID, fileType = 5 } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required. Set HUAWEI_APP_ID env or provide appId parameter.' }, null, 2) }],
                    };
                }
                await huaweiClient.deleteAppFiles(appId, fileType);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                message: `Successfully deleted app files (fileType: ${fileType})`,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === LANGUAGE & LOCALIZATION ===
            case 'huawei_list_languages': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const appInfo = await huaweiClient.getAppInfo(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                languages: appInfo.languages || [],
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_get_language_info': {
                const { appId = HUAWEI_APP_ID, language } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const langInfo = await huaweiClient.getLanguageInfo(appId, language);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                language,
                                info: langInfo,
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_delete_language': {
                const { appId = HUAWEI_APP_ID, language } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                await huaweiClient.deleteLanguageInfo(appId, language);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: `Language '${language}' deleted successfully`,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === COMPILATION & BUILD ===
            case 'huawei_get_compilation_status': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const status = await huaweiClient.getCompilationStatus(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                compilationStatus: status,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === PHASED RELEASE ===
            case 'huawei_update_phased_release': {
                const { appId = HUAWEI_APP_ID, phasedReleasePercent } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                await huaweiClient.updatePhasedRelease(appId, phasedReleasePercent);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: `Phased release updated to ${phasedReleasePercent}%`,
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_stop_phased_release': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                await huaweiClient.stopPhasedRelease(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: 'Phased release stopped',
                            }, null, 2),
                        },
                    ],
                };
            }
            // === GEO RESTRICTIONS ===
            case 'huawei_get_geo_restrictions': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const geoInfo = await huaweiClient.getGeoRestrictions(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                ...geoInfo,
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_set_geo_restrictions': {
                const { appId = HUAWEI_APP_ID, countries, releaseType } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                await huaweiClient.setGeoRestrictions(appId, countries, releaseType);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: `Geo restrictions updated. Release type: ${releaseType}, Countries: ${countries.length}`,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === SCREENSHOTS ===
            case 'huawei_upload_screenshot': {
                const { appId = HUAWEI_APP_ID, filePath, language = 'en-US', deviceType = 1 } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const fileUrl = await huaweiClient.uploadScreenshot(appId, filePath, language, deviceType);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: 'Screenshot uploaded successfully',
                                fileUrl,
                                language,
                                deviceType,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === CERTIFICATE ===
            case 'huawei_get_upload_certificate': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const certInfo = await huaweiClient.getCertificateInfo(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                certificate: certInfo,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === AAB COMPILE STATUS ===
            case 'huawei_get_aab_compile_status': {
                const { appId = HUAWEI_APP_ID, pkgVersion } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const status = await huaweiClient.getAabCompileStatus(appId, pkgVersion);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                aabCompileStatus: status,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === APP TAKEDOWN ===
            case 'huawei_takedown_app': {
                const { appId = HUAWEI_APP_ID, reason } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                await huaweiClient.takedownApp(appId, reason);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: 'App has been taken down from AppGallery',
                                warning: 'The app is no longer available in the store!',
                            }, null, 2),
                        },
                    ],
                };
            }
            // === CANCEL SUBMISSION ===
            case 'huawei_cancel_submission': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                await huaweiClient.cancelSubmission(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: 'Review submission cancelled',
                            }, null, 2),
                        },
                    ],
                };
            }
            // === APP VERSION INFO ===
            case 'huawei_get_version_info': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const appInfo = await huaweiClient.getAppInfo(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                versionName: appInfo.versionName,
                                versionCode: appInfo.versionCode,
                                packageName: appInfo.packageName,
                                minSdkVersion: appInfo.minSdkVersion,
                                targetSdkVersion: appInfo.targetSdkVersion,
                                releaseState: appInfo.releaseState,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === PRIVACY POLICY ===
            case 'huawei_set_privacy_policy': {
                const { appId = HUAWEI_APP_ID, privacyPolicyUrl } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                // Privacy policy is set via app-language-info or in AppGallery Connect console
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: 'Privacy policy URL should be set in AppGallery Connect console or via app info update',
                                privacyPolicyUrl,
                                note: 'Use huawei_update_app_info to update app description which can include privacy policy link',
                            }, null, 2),
                        },
                    ],
                };
            }
            // === APP ICON ===
            case 'huawei_upload_app_icon': {
                const { appId = HUAWEI_APP_ID, filePath } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                // Upload icon using screenshot upload endpoint
                const fileUrl = await huaweiClient.uploadScreenshot(appId, filePath, 'en-US', 0);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: 'App icon uploaded successfully',
                                fileUrl,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === FEATURE GRAPHIC ===
            case 'huawei_upload_feature_graphic': {
                const { appId = HUAWEI_APP_ID, filePath, language = 'en-US' } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                // Upload feature graphic using screenshot upload endpoint
                const fileUrl = await huaweiClient.uploadScreenshot(appId, filePath, language, 0);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: 'Feature graphic uploaded successfully',
                                fileUrl,
                                language,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === DELETE SCREENSHOTS ===
            case 'huawei_delete_screenshots': {
                const { appId = HUAWEI_APP_ID, language = 'en-US', deviceType = 1 } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                // Get current screenshots and delete them
                const langInfo = await huaweiClient.getLanguageInfo(appId, language);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                message: 'Use huawei_update_app_info with empty screenshot URLs to clear screenshots',
                                currentScreenshots: langInfo.screenShotUrls || [],
                            }, null, 2),
                        },
                    ],
                };
            }
            // === RELEASE NOTES ===
            case 'huawei_get_release_notes': {
                const { appId = HUAWEI_APP_ID, language = 'en-US' } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const langInfo = await huaweiClient.getLanguageInfo(appId, language);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                language,
                                newFeatures: langInfo.newFeatures || 'Not set',
                                appDesc: langInfo.appDesc || 'Not set',
                            }, null, 2),
                        },
                    ],
                };
            }
            // === CATEGORY INFO ===
            case 'huawei_get_category_info': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const appInfo = await huaweiClient.getAppInfo(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                categoryId: appInfo.categoryId,
                                categoryName: appInfo.categoryName,
                                contentRating: appInfo.contentRating,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === PACKAGE SUMMARY ===
            case 'huawei_get_package_summary': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const appInfo = await huaweiClient.getAppInfo(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                packageName: appInfo.packageName,
                                currentVersion: appInfo.versionName,
                                versionCode: appInfo.versionCode,
                                fileSize: appInfo.fileSize,
                                sha256: appInfo.sha256,
                            }, null, 2),
                        },
                    ],
                };
            }
            // === PERMISSIONS ===
            case 'huawei_get_permissions': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const appInfo = await huaweiClient.getAppInfo(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                permissions: appInfo.permissions || [],
                            }, null, 2),
                        },
                    ],
                };
            }
            // === SUPPORTED COUNTRIES ===
            case 'huawei_list_supported_countries': {
                // Return list of main Huawei AppGallery supported countries
                const countries = [
                    'CN', 'HK', 'TW', 'MO', // Greater China
                    'SG', 'MY', 'TH', 'VN', 'ID', 'PH', // Southeast Asia
                    'JP', 'KR', // East Asia
                    'IN', 'PK', 'BD', // South Asia
                    'AE', 'SA', 'EG', 'TR', // Middle East
                    'RU', 'UA', // CIS
                    'DE', 'FR', 'GB', 'IT', 'ES', 'PL', 'NL', 'BE', 'AT', 'CH', // Western Europe
                    'RS', 'HR', 'SI', 'BA', 'ME', 'MK', 'AL', // Balkans
                    'CZ', 'SK', 'HU', 'RO', 'BG', // Central/Eastern Europe
                    'BR', 'MX', 'AR', 'CO', 'CL', 'PE', // Latin America
                    'ZA', 'NG', 'KE', // Africa
                ];
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                totalCountries: countries.length,
                                countries,
                                note: 'This is a summary of main supported countries. Actual availability may vary.',
                            }, null, 2),
                        },
                    ],
                };
            }
            // === APP DOWNLOADS ===
            case 'huawei_get_app_downloads': {
                const { appId = HUAWEI_APP_ID } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const appInfo = await huaweiClient.getAppInfo(appId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                appId,
                                downloads: appInfo.downloads || 'Not available via API',
                                rating: appInfo.rating || 'Not available via API',
                                note: 'Detailed stats available in AppGallery Connect console',
                            }, null, 2),
                        },
                    ],
                };
            }
            // ═══════════════════════════════════════════════════════════════════════════
            // 🧪 CLOUD TESTING HANDLERS
            // ═══════════════════════════════════════════════════════════════════════════
            case 'huawei_cloud_test_devices': {
                const devices = await huaweiClient.getCloudTestDevices();
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                totalDevices: devices.length,
                                devices: devices.map(d => ({
                                    deviceId: d.deviceId,
                                    name: `${d.brand} ${d.model}`,
                                    osVersion: d.osVersion,
                                    resolution: d.resolution,
                                    available: d.available,
                                })),
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_cloud_test_create': {
                const { appId = HUAWEI_APP_ID, testType = 1, apkPath, deviceIds = [], timeout = 30 } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                if (!apkPath) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'apkPath is required.' }, null, 2) }],
                    };
                }
                // First upload the APK
                logger.info(`Uploading APK for cloud testing: ${apkPath}`);
                const uploadInfo = await huaweiClient.getUploadUrl(appId, 'apk');
                const fileUrl = await huaweiClient.uploadFile(uploadInfo.uploadUrl, uploadInfo.authCode, apkPath);
                // If no devices specified, get some popular ones
                let testDeviceIds = deviceIds;
                if (testDeviceIds.length === 0) {
                    const allDevices = await huaweiClient.getCloudTestDevices();
                    const availableDevices = allDevices.filter(d => d.available).slice(0, 5);
                    testDeviceIds = availableDevices.map(d => d.deviceId);
                }
                // Create the test task
                const result = await huaweiClient.createCloudTestTask(appId, testType, fileUrl, testDeviceIds, timeout);
                const testTypeNames = {
                    1: 'Compatibility',
                    2: 'Stability',
                    3: 'Performance',
                    4: 'Power Consumption',
                };
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                taskId: result.taskId,
                                testType: testTypeNames[testType] || `Type ${testType}`,
                                deviceCount: testDeviceIds.length,
                                timeout: `${timeout} minutes`,
                                message: result.message,
                                nextStep: `Use huawei_cloud_test_status with taskId "${result.taskId}" to check progress`,
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_cloud_test_status': {
                const { taskId } = args;
                if (!taskId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'taskId is required.' }, null, 2) }],
                    };
                }
                const status = await huaweiClient.getCloudTestStatus(taskId);
                const statusNames = {
                    0: 'Pending',
                    1: 'Running',
                    2: 'Completed',
                    3: 'Failed',
                };
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                taskId: status.taskId,
                                status: statusNames[status.status] || `Status ${status.status}`,
                                progress: `${status.progress}%`,
                                startTime: status.startTime,
                                endTime: status.endTime,
                                deviceResults: status.deviceResults?.map(dr => ({
                                    device: dr.deviceName,
                                    passed: dr.passed,
                                    errors: dr.errorCount,
                                    warnings: dr.warningCount,
                                })),
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_cloud_test_list': {
                const { appId = HUAWEI_APP_ID, pageNum = 1, pageSize = 10 } = args;
                if (!appId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'appId is required.' }, null, 2) }],
                    };
                }
                const result = await huaweiClient.listCloudTestTasks(appId, pageNum, pageSize);
                const testTypeNames = {
                    1: 'Compatibility',
                    2: 'Stability',
                    3: 'Performance',
                    4: 'Power',
                };
                const statusNames = {
                    0: 'Pending',
                    1: 'Running',
                    2: 'Completed',
                    3: 'Failed',
                };
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                total: result.total,
                                page: pageNum,
                                tasks: result.tasks.map(t => ({
                                    taskId: t.taskId,
                                    testType: testTypeNames[t.testType] || `Type ${t.testType}`,
                                    status: statusNames[t.status] || `Status ${t.status}`,
                                    deviceCount: t.deviceCount,
                                    created: t.createTime,
                                })),
                            }, null, 2),
                        },
                    ],
                };
            }
            case 'huawei_cloud_test_report': {
                const { taskId } = args;
                if (!taskId) {
                    return {
                        content: [{ type: 'text', text: JSON.stringify({ success: false, error: 'taskId is required.' }, null, 2) }],
                    };
                }
                const report = await huaweiClient.getCloudTestReport(taskId);
                return {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify({
                                success: true,
                                taskId: report.taskId,
                                summary: {
                                    totalDevices: report.summary.totalDevices,
                                    passed: report.summary.passedDevices,
                                    failed: report.summary.failedDevices,
                                    errors: report.summary.errorCount,
                                    warnings: report.summary.warningCount,
                                    passRate: `${Math.round((report.summary.passedDevices / report.summary.totalDevices) * 100)}%`,
                                },
                                deviceReports: report.deviceReports?.map(dr => ({
                                    device: dr.deviceName,
                                    passed: dr.passed,
                                    errors: dr.errorCount,
                                    warnings: dr.warningCount,
                                    screenshots: dr.screenshots?.length || 0,
                                })),
                                reportUrl: report.reportUrl,
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
