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
    appName?: string;
    packageName?: string;
    versionCode?: number;
    versionName?: string;
    versionNumber?: string;
    releaseState: number;
    defaultLang?: string;
    updateTime?: string;
    onShelfVersionNumber?: string;
    onShelfVersionCode?: number;
    onShelfVersionId?: string;
    projectId?: string;
    languages?: string[];
    minSdkVersion?: number;
    targetSdkVersion?: number;
    categoryId?: string;
    categoryName?: string;
    contentRating?: string;
    fileSize?: number;
    sha256?: string;
    permissions?: string[];
    downloads?: number | string;
    rating?: number | string;
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
    /**
     * 📜 Get All Language Info
     * GET /publish/v2/app-language-info
     */
    getLanguageInfo(appId: string, lang?: string): Promise<any>;
    /**
     * 🗑️ Delete Language Info
     * DELETE /publish/v2/app-language-info
     */
    deleteLanguageInfo(appId: string, lang: string): Promise<void>;
    /**
     * 🌍 Get Geo Restrictions (Country Availability)
     * GET /publish/v2/app-info (includes releaseCountry in response)
     */
    getGeoRestrictions(appId: string): Promise<any>;
    /**
     * 🌍 Set Geo Restrictions
     * PUT /publish/v2/app-info
     */
    setGeoRestrictions(appId: string, countries: string[], releaseType: number): Promise<void>;
    /**
     * 📈 Update Phased Release
     * PUT /publish/v2/phased-release
     */
    updatePhasedRelease(appId: string, percent: number): Promise<void>;
    /**
     * ⏹️ Stop Phased Release
     * DELETE /publish/v2/phased-release
     */
    stopPhasedRelease(appId: string): Promise<void>;
    /**
     * 📸 Upload Screenshot
     * POST to OBS upload URL then update app info
     */
    uploadScreenshot(appId: string, filePath: string, language?: string, deviceType?: number): Promise<string>;
    /**
     * 📜 Get Certificate Info
     * GET /publish/v2/upload-cert
     */
    getCertificateInfo(appId: string): Promise<any>;
    /**
     * 📊 Get AAB Compile Status
     * GET /publish/v2/aab/compile/status
     */
    getAabCompileStatus(appId: string, pkgVersion?: string): Promise<any>;
    /**
     * 🔴 Take Down App
     * POST /publish/v2/app-takedown
     */
    takedownApp(appId: string, reason?: string): Promise<void>;
    /**
     * ❌ Cancel Submission
     * POST /publish/v2/app-cancel-submit
     */
    cancelSubmission(appId: string): Promise<void>;
    /**
     * 📱 Get Available Test Devices
     * GET /cloudtest/v1/devices
     */
    getCloudTestDevices(): Promise<CloudTestDevice[]>;
    /**
     * 🚀 Create Cloud Test Task
     * POST /cloudtest/v1/tasks
     *
     * @param appId - App ID
     * @param testType - Test type: 1=Compatibility, 2=Stability, 3=Performance, 4=Power
     * @param fileUrl - URL of uploaded APK (use getUploadUrl + uploadFile first)
     * @param deviceIds - Array of device IDs to test on
     * @param timeout - Test timeout in minutes (default 30)
     */
    createCloudTestTask(appId: string, testType: number, fileUrl: string, deviceIds: string[], timeout?: number): Promise<CloudTestTaskResult>;
    /**
     * 📊 Get Cloud Test Task Status
     * GET /cloudtest/v1/tasks/{taskId}
     */
    getCloudTestStatus(taskId: string): Promise<CloudTestStatus>;
    /**
     * 📋 List Cloud Test Tasks
     * GET /cloudtest/v1/tasks
     */
    listCloudTestTasks(appId: string, pageNum?: number, pageSize?: number): Promise<CloudTestTaskList>;
    /**
     * 📥 Get Cloud Test Report
     * GET /cloudtest/v1/tasks/{taskId}/report
     */
    getCloudTestReport(taskId: string): Promise<CloudTestReport>;
}
export interface CloudTestDevice {
    deviceId: string;
    deviceName: string;
    brand: string;
    model: string;
    osVersion: string;
    resolution: string;
    available: boolean;
}
export interface CloudTestTaskResult {
    taskId: string;
    message: string;
}
export interface CloudTestStatus {
    taskId: string;
    status: number;
    statusDesc: string;
    progress: number;
    startTime?: string;
    endTime?: string;
    deviceResults?: CloudTestDeviceResult[];
}
export interface CloudTestDeviceResult {
    deviceId: string;
    deviceName: string;
    status: number;
    passed: boolean;
    errorCount: number;
    warningCount: number;
    screenshots?: string[];
    logs?: string;
}
export interface CloudTestTask {
    taskId: string;
    testType: number;
    status: number;
    createTime: string;
    deviceCount: number;
}
export interface CloudTestTaskList {
    tasks: CloudTestTask[];
    total: number;
}
export interface CloudTestReport {
    taskId: string;
    testType: number;
    summary: {
        totalDevices: number;
        passedDevices: number;
        failedDevices: number;
        errorCount: number;
        warningCount: number;
    };
    deviceReports: CloudTestDeviceResult[];
    reportUrl?: string;
}
