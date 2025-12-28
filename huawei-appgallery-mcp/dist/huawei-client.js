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
// Hardcoded fallback credentials (VS Code env vars don't work reliably)
const FALLBACK_CLIENT_ID = '1850740994484473152';
const FALLBACK_CLIENT_SECRET = 'F4CC48ADE493A712D729DDF8B7A11542591BDBC52AD2999E950CC7BED1DEDC98';
export class HuaweiAppGalleryClient {
    credentials;
    accessToken = null;
    tokenExpiry = 0;
    constructor(credentials) {
        // Use fallback if credentials are empty
        this.credentials = {
            clientId: credentials.clientId || FALLBACK_CLIENT_ID,
            clientSecret: credentials.clientSecret || FALLBACK_CLIENT_SECRET
        };
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
        const body = { appId };
        if (releaseTime) {
            body.releaseTime = releaseTime;
        }
        const response = await fetch(`${PUBLISH_API}/app-submit`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'client_id': this.credentials.clientId,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(body),
        });
        if (!response.ok) {
            throw new Error(`Failed to submit app: ${response.status}`);
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
}
