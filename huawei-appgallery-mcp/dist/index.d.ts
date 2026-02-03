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
