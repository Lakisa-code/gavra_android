/**
 * 🔐 Huawei AppGallery Connect API Client
 * Handles authentication and API calls to AppGallery Connect
 *
 * API Documentation: https://developer.huawei.com/consumer/en/doc/AppGallery-connect-References/agcapi-overview-0000001158245067
 */
import FormData from 'form-data';
import * as fs from 'fs';
import fetch from 'node-fetch';
import * as path from 'path';
// API Base URLs
const AUTH_URL = 'https://connect-api.cloud.huawei.com/api/oauth2/v1/token';
const API_BASE = 'https://connect-api.cloud.huawei.com/api';
const PUBLISH_API = `${API_BASE}/publish/v2`;
export class HuaweiAppGalleryClient {
    credentials;
    accessToken = null;
    tokenExpiry = 0;
    constructor(credentials) {
        if (!credentials.clientId || !credentials.clientSecret) {
            throw new Error('HuaweiAppGalleryClient: clientId and clientSecret are required');
        }
        this.credentials = credentials;
    }
    /**
     * 🔐 Get Access Token
     * POST https://connect-api.cloud.huawei.com/api/oauth2/v1/token
     */
    async getAccessToken() {
        // Return cached token if still valid
        if (this.accessToken && Date.now() < this.tokenExpiry) {
            return this.accessToken;
        }
        const body = JSON.stringify({
            grant_type: 'client_credentials',
            client_id: this.credentials.clientId,
            client_secret: this.credentials.clientSecret
        });
        const response = await fetch(AUTH_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: body,
        });
        if (!response.ok) {
            throw new Error(`Authentication failed: ${response.status} ${response.statusText}`);
        }
        const data = await response.json();
        this.accessToken = data.access_token;
        // Expire 5 minutes before actual expiry
        this.tokenExpiry = Date.now() + (data.expires_in - 300) * 1000;
        return this.accessToken;
    }
    /**
     * 📱 Get App Info
     * GET /publish/v2/app-info
     */
    async getAppInfo(appId) {
        const token = await this.getAccessToken();
        const url = `${PUBLISH_API}/app-info?appId=${appId}`;
        console.error('[DEBUG] getAppInfo URL:', url);
        console.error('[DEBUG] client_id:', this.credentials.clientId);
        console.error('[DEBUG] token length:', token?.length);
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        console.error('[DEBUG] response status:', response.status);
        if (!response.ok) {
            const text = await response.text();
            console.error('[DEBUG] error body:', text);
            throw new Error(`Failed to get app info: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${JSON.stringify(data.ret)}`);
        }
        return data.appInfo;
    }
    /**
     * 📤 Get Upload URL for APK/AAB
     * GET /publish/v2/upload-url
     */
    async getUploadUrl(appId, suffix = 'apk') {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/upload-url?appId=${appId}&suffix=${suffix}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to get upload URL: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${JSON.stringify(data.ret)}`);
        }
        return {
            uploadUrl: data.uploadUrl,
            authCode: data.authCode,
            fileId: '', // Will be returned after upload
        };
    }
    /**
     * 📤 Upload APK/AAB File
     * POST to uploadUrl
     */
    async uploadFile(uploadUrl, authCode, filePath) {
        const fileBuffer = fs.readFileSync(filePath);
        const fileName = path.basename(filePath);
        const formData = new FormData();
        formData.append('file', fileBuffer, fileName);
        formData.append('authCode', authCode);
        formData.append('fileCount', '1');
        const response = await fetch(uploadUrl, {
            method: 'POST',
            body: formData,
            headers: formData.getHeaders(),
        });
        if (!response.ok) {
            throw new Error(`Upload failed: ${response.status}`);
        }
        const data = await response.json();
        return data.result.UploadFileRsp.fileInfoList[0].fileDestUlr;
    }
    /**
     * 🗑️ Delete App Files (APK/AAB)
     * DELETE /publish/v2/app-file-info
     *
     * Deletes uploaded package files from the draft version.
     * fileType: 5 = APK, 3 = RPK
     */
    async deleteAppFiles(appId, fileType = 5) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-file-info?appId=${appId}&fileType=${fileType}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            const text = await response.text();
            console.error('[DEBUG] deleteAppFiles error:', text);
            throw new Error(`Failed to delete app files: ${response.status} - ${text}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${data.ret.msg}`);
        }
    }
    /**
     * 📝 Update App File Info (after upload)
     * PUT /publish/v2/app-file-info
     */
    async updateAppFileInfo(appId, fileUrl) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-file-info`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                appId,
                files: [
                    {
                        fileName: 'app-release.apk',
                        fileDestUrl: fileUrl,
                    },
                ],
            }),
        });
        if (!response.ok) {
            throw new Error(`Failed to update file info: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${data.ret.msg}`);
        }
    }
    /**
     * 🚀 Submit App for Review
     * POST /publish/v2/app-submit
     */
    async submitForReview(appId, releaseTime) {
        const token = await this.getAccessToken();
        // Build query params - appId is required in query string
        let url = `${PUBLISH_API}/app-submit?appId=${appId}`;
        if (releaseTime) {
            url += `&releaseTime=${encodeURIComponent(releaseTime)}`;
        }
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
        });
        if (!response.ok) {
            const text = await response.text();
            console.error('[DEBUG] submitForReview error:', text);
            throw new Error(`Failed to submit app: ${response.status} - ${text}`);
        }
        return await response.json();
    }
    /**
     * 📊 Get App Compilation Status
     * GET /publish/v2/package/compile/status
     */
    async getCompilationStatus(appId) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/package/compile/status?appId=${appId}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to get compilation status: ${response.status}`);
        }
        const data = await response.json();
        if (data.pkgStateList && data.pkgStateList.length > 0) {
            return {
                status: data.pkgStateList[0].pkgState,
                statusDesc: data.pkgStateList[0].pkgStateDesc,
            };
        }
        return { status: -1, statusDesc: 'Unknown' };
    }
    /**
     * 📝 Update App Language Info (title, description, etc.)
     * PUT /publish/v2/app-language-info
     */
    async updateLanguageInfo(appId, lang, data) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-language-info`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                appId,
                lang,
                ...data,
            }),
        });
        if (!response.ok) {
            throw new Error(`Failed to update language info: ${response.status}`);
        }
        const result = await response.json();
        if (result.ret.code !== 0) {
            throw new Error(`API Error: ${result.ret.msg}`);
        }
    }
    /**
     * 📸 Get Upload URL for Screenshots
     * GET /publish/v2/upload-url/for-obs
     */
    async getScreenshotUploadUrl(appId, suffix = 'png') {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/upload-url/for-obs?appId=${appId}&suffix=${suffix}&resourceType=2`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to get screenshot upload URL: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${JSON.stringify(data.ret)}`);
        }
        return {
            uploadUrl: data.uploadUrl,
            authCode: data.authCode,
            fileId: '',
        };
    }
    /**
     * 📜 List All Apps
     * GET /publish/v2/app-list
     */
    async listApps() {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-list`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to list apps: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${JSON.stringify(data.ret)}`);
        }
        return data.appInfos || [];
    }
    /**
     * 🔐 Set Test Account Info for Reviewers
     * PUT /publish/v2/app-info
     *
     * This sets the test account credentials that Huawei reviewers will use
     * to test the app during the review process.
     */
    async setTestAccountInfo(appId, testAccount) {
        const token = await this.getAccessToken();
        const body = {
            testAccount: testAccount.account,
            testPassword: testAccount.password,
            testRemark: testAccount.accountRemark || '',
        };
        console.error('[DEBUG] setTestAccountInfo request:', JSON.stringify(body, null, 2));
        // appId must be in query string, not in body
        const response = await fetch(`${PUBLISH_API}/app-info?appId=${appId}`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(body),
        });
        console.error('[DEBUG] setTestAccountInfo response status:', response.status);
        if (!response.ok) {
            const text = await response.text();
            console.error('[DEBUG] setTestAccountInfo error:', text);
            throw new Error(`Failed to set test account info: ${response.status} - ${text}`);
        }
        const result = await response.json();
        console.error('[DEBUG] setTestAccountInfo result:', JSON.stringify(result, null, 2));
        if (result.ret.code !== 0) {
            throw new Error(`API Error: ${result.ret.msg}`);
        }
    }
    /**
     * 📋 Get Test Account Info
     * GET /publish/v2/app-info (includes test account in response)
     */
    async getTestAccountInfo(appId) {
        const token = await this.getAccessToken();
        const url = `${PUBLISH_API}/app-info?appId=${appId}`;
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to get test account info: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${JSON.stringify(data.ret)}`);
        }
        return {
            testAccount: data.appInfo.testAccount,
            testPassword: data.appInfo.testPassword,
            testRemark: data.appInfo.testRemark,
        };
    }
    /**
     * 📜 Get All Language Info
     * GET /publish/v2/app-language-info
     */
    async getLanguageInfo(appId, lang) {
        const token = await this.getAccessToken();
        let url = `${PUBLISH_API}/app-language-info?appId=${appId}`;
        if (lang) {
            url += `&lang=${lang}`;
        }
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to get language info: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${JSON.stringify(data.ret)}`);
        }
        return data;
    }
    /**
     * 🗑️ Delete Language Info
     * DELETE /publish/v2/app-language-info
     */
    async deleteLanguageInfo(appId, lang) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-language-info?appId=${appId}&lang=${lang}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to delete language: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${data.ret.msg}`);
        }
    }
    /**
     * 🌍 Get Geo Restrictions (Country Availability)
     * GET /publish/v2/app-info (includes releaseCountry in response)
     */
    async getGeoRestrictions(appId) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-info?appId=${appId}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to get geo restrictions: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${JSON.stringify(data.ret)}`);
        }
        return {
            releaseType: data.appInfo.releaseType,
            releaseCountry: data.appInfo.releaseCountry,
        };
    }
    /**
     * 🌍 Set Geo Restrictions
     * PUT /publish/v2/app-info
     */
    async setGeoRestrictions(appId, countries, releaseType) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-info?appId=${appId}`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                releaseType,
                releaseCountry: countries.join(';'),
            }),
        });
        if (!response.ok) {
            throw new Error(`Failed to set geo restrictions: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${data.ret.msg}`);
        }
    }
    /**
     * 📈 Update Phased Release
     * PUT /publish/v2/phased-release
     */
    async updatePhasedRelease(appId, percent) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/phased-release?appId=${appId}`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                phasedPercent: percent,
            }),
        });
        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Failed to update phased release: ${response.status} - ${text}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${data.ret.msg}`);
        }
    }
    /**
     * ⏹️ Stop Phased Release
     * DELETE /publish/v2/phased-release
     */
    async stopPhasedRelease(appId) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/phased-release?appId=${appId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to stop phased release: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${data.ret.msg}`);
        }
    }
    /**
     * 📸 Upload Screenshot
     * POST to OBS upload URL then update app info
     */
    async uploadScreenshot(appId, filePath, language = 'en-US', deviceType = 1) {
        // Get upload URL for screenshot
        const suffix = path.extname(filePath).slice(1) || 'png';
        const uploadInfo = await this.getScreenshotUploadUrl(appId, suffix);
        // Upload file
        const fileBuffer = fs.readFileSync(filePath);
        const fileName = path.basename(filePath);
        const formData = new FormData();
        formData.append('file', fileBuffer, fileName);
        formData.append('authCode', uploadInfo.authCode);
        formData.append('fileCount', '1');
        const uploadResponse = await fetch(uploadInfo.uploadUrl, {
            method: 'POST',
            body: formData,
            headers: formData.getHeaders(),
        });
        if (!uploadResponse.ok) {
            throw new Error(`Screenshot upload failed: ${uploadResponse.status}`);
        }
        const uploadData = await uploadResponse.json();
        const fileUrl = uploadData.result.UploadFileRsp.fileInfoList[0].fileDestUlr;
        // Now update app language info with the screenshot
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-language-info`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                appId,
                lang: language,
                deviceMaterials: [
                    {
                        deviceType,
                        appIcon: undefined,
                        screenShots: fileUrl,
                    },
                ],
            }),
        });
        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Failed to update screenshot: ${response.status} - ${text}`);
        }
        return fileUrl;
    }
    /**
     * 📜 Get Certificate Info
     * GET /publish/v2/upload-cert
     */
    async getCertificateInfo(appId) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/upload-cert?appId=${appId}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to get certificate info: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${JSON.stringify(data.ret)}`);
        }
        return data.certInfo || data;
    }
    /**
     * 📊 Get AAB Compile Status
     * GET /publish/v2/aab/compile/status
     */
    async getAabCompileStatus(appId, pkgVersion) {
        const token = await this.getAccessToken();
        let url = `${PUBLISH_API}/aab/compile/status?appId=${appId}`;
        if (pkgVersion) {
            url += `&pkgVersion=${pkgVersion}`;
        }
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            throw new Error(`Failed to get AAB compile status: ${response.status}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${JSON.stringify(data.ret)}`);
        }
        return data;
    }
    /**
     * 🔴 Take Down App
     * POST /publish/v2/app-takedown
     */
    async takedownApp(appId, reason) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-takedown?appId=${appId}`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                reason: reason || 'App takedown requested via API',
            }),
        });
        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Failed to take down app: ${response.status} - ${text}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${data.ret.msg}`);
        }
    }
    /**
     * ❌ Cancel Submission
     * POST /publish/v2/app-cancel-submit
     */
    async cancelSubmission(appId) {
        const token = await this.getAccessToken();
        const response = await fetch(`${PUBLISH_API}/app-cancel-submit?appId=${appId}`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Failed to cancel submission: ${response.status} - ${text}`);
        }
        const data = await response.json();
        if (data.ret.code !== 0) {
            throw new Error(`API Error: ${data.ret.msg}`);
        }
    }
    // ═══════════════════════════════════════════════════════════════════════════
    // 🧪 CLOUD TESTING API
    // ═══════════════════════════════════════════════════════════════════════════
    /**
     * 📱 Get Available Test Devices
     * GET /cloudtest/v1/devices
     */
    async getCloudTestDevices() {
        const token = await this.getAccessToken();
        const response = await fetch(`${API_BASE}/cloudtest/v1/devices`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Failed to get test devices: ${response.status} - ${text}`);
        }
        const data = await response.json();
        if (data.ret?.code !== 0) {
            throw new Error(`API Error: ${data.ret?.msg || 'Unknown error'}`);
        }
        return data.deviceList || [];
    }
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
    async createCloudTestTask(appId, testType, fileUrl, deviceIds, timeout = 30) {
        const token = await this.getAccessToken();
        const body = {
            appId,
            testType,
            apkPath: fileUrl,
            deviceIdList: deviceIds,
            timeout,
        };
        const response = await fetch(`${API_BASE}/cloudtest/v1/tasks`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(body),
        });
        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Failed to create test task: ${response.status} - ${text}`);
        }
        const data = await response.json();
        if (data.ret?.code !== 0) {
            throw new Error(`API Error: ${data.ret?.msg || 'Unknown error'}`);
        }
        return {
            taskId: data.taskId,
            message: 'Test task created successfully',
        };
    }
    /**
     * 📊 Get Cloud Test Task Status
     * GET /cloudtest/v1/tasks/{taskId}
     */
    async getCloudTestStatus(taskId) {
        const token = await this.getAccessToken();
        const response = await fetch(`${API_BASE}/cloudtest/v1/tasks/${taskId}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Failed to get test status: ${response.status} - ${text}`);
        }
        const data = await response.json();
        if (data.ret?.code !== 0) {
            throw new Error(`API Error: ${data.ret?.msg || 'Unknown error'}`);
        }
        return data.taskInfo;
    }
    /**
     * 📋 List Cloud Test Tasks
     * GET /cloudtest/v1/tasks
     */
    async listCloudTestTasks(appId, pageNum = 1, pageSize = 10) {
        const token = await this.getAccessToken();
        const response = await fetch(`${API_BASE}/cloudtest/v1/tasks?appId=${appId}&pageNum=${pageNum}&pageSize=${pageSize}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Failed to list test tasks: ${response.status} - ${text}`);
        }
        const data = await response.json();
        if (data.ret?.code !== 0) {
            throw new Error(`API Error: ${data.ret?.msg || 'Unknown error'}`);
        }
        return {
            tasks: data.taskList || [],
            total: data.total || 0,
        };
    }
    /**
     * 📥 Get Cloud Test Report
     * GET /cloudtest/v1/tasks/{taskId}/report
     */
    async getCloudTestReport(taskId) {
        const token = await this.getAccessToken();
        const response = await fetch(`${API_BASE}/cloudtest/v1/tasks/${taskId}/report`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
            },
        });
        if (!response.ok) {
            const text = await response.text();
            throw new Error(`Failed to get test report: ${response.status} - ${text}`);
        }
        const data = await response.json();
        if (data.ret?.code !== 0) {
            throw new Error(`API Error: ${data.ret?.msg || 'Unknown error'}`);
        }
        return data.report;
    }
}
