/**
 * 🔐 Huawei AppGallery Connect API Client
 * Handles authentication and API calls to AppGallery Connect
 *
 * API Documentation: https://developer.huawei.com/consumer/en/doc/AppGallery-connect-References/agcapi-overview-0000001158245067
 */
export interface HuaweiCredentials {
    clientId: string;
    clientSecret: string;
}
export interface TokenResponse {
    access_token: string;
    expires_in: number;
    token_type: string;
}
export interface AppInfo {
    appId: string;
    appName: string;
    packageName: string;
    versionCode: string;
    versionName: string;
    releaseState: number;
    languages: string[];
}
export interface UploadUrlResponse {
    uploadUrl: string;
    authCode: string;
    fileId: string;
}
export interface AppSubmitResult {
    ret: {
        code: number;
        msg: string;
    };
}
export declare class HuaweiAppGalleryClient {
    private credentials;
    private accessToken;
    private tokenExpiry;
    constructor(credentials: HuaweiCredentials);
    /**
     * 🔐 Get Access Token
     * POST https://connect-api.cloud.huawei.com/api/oauth2/v1/token
     */
    getAccessToken(): Promise<string>;
    /**
     * 📱 Get App Info
     * GET /publish/v2/app-info
     */
    getAppInfo(appId: string): Promise<AppInfo>;
    /**
     * 📤 Get Upload URL for APK/AAB
     * GET /publish/v2/upload-url
     */
    getUploadUrl(appId: string, suffix?: 'apk' | 'aab'): Promise<UploadUrlResponse>;
    /**
     * 📤 Upload APK/AAB File
     * POST to uploadUrl
     */
    uploadFile(uploadUrl: string, authCode: string, filePath: string): Promise<string>;
    /**
     * 🗑️ Delete App Files (APK/AAB)
     * DELETE /publish/v2/app-file-info
     *
     * Deletes uploaded package files from the draft version.
     * fileType: 5 = APK, 3 = RPK
     */
    deleteAppFiles(appId: string, fileType?: number): Promise<void>;
    /**
     * 📝 Update App File Info (after upload)
     * PUT /publish/v2/app-file-info
     */
    updateAppFileInfo(appId: string, fileUrl: string): Promise<void>;
    /**
     * 🚀 Submit App for Review
     * POST /publish/v2/app-submit
     */
    submitForReview(appId: string, releaseTime?: string): Promise<AppSubmitResult>;
    /**
     * 📊 Get App Compilation Status
     * GET /publish/v2/package/compile/status
     */
    getCompilationStatus(appId: string): Promise<{
        status: number;
        statusDesc: string;
    }>;
    /**
     * 📝 Update App Language Info (title, description, etc.)
     * PUT /publish/v2/app-language-info
     */
    updateLanguageInfo(appId: string, lang: string, data: {
        appName?: string;
        appDesc?: string;
        briefInfo?: string;
        newFeatures?: string;
    }): Promise<void>;
    /**
     * 📸 Get Upload URL for Screenshots
     * GET /publish/v2/upload-url/for-obs
     */
    getScreenshotUploadUrl(appId: string, suffix?: string): Promise<UploadUrlResponse>;
    /**
     * 📜 List All Apps
     * GET /publish/v2/app-list
     */
    listApps(): Promise<AppInfo[]>;
    /**
     * 🔐 Set Test Account Info for Reviewers
     * PUT /publish/v2/app-info
     *
     * This sets the test account credentials that Huawei reviewers will use
     * to test the app during the review process.
     */
    setTestAccountInfo(appId: string, testAccount: {
        account: string;
        password: string;
        accountRemark?: string;
    }): Promise<void>;
    /**
     * 📋 Get Test Account Info
     * GET /publish/v2/app-info (includes test account in response)
     */
    getTestAccountInfo(appId: string): Promise<{
        testAccount?: string;
        testPassword?: string;
        testRemark?: string;
    }>;
}
