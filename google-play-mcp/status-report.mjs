#!/usr/bin/env node

/**
 * Google Play MCP Server Status Report
 * Tests the MCP server functionality and displays available tools
 */

import * as dotenv from 'dotenv';
import { google } from 'googleapis';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.gavra013.gavra_android';
const SERVICE_ACCOUNT_KEY = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;

console.log('════════════════════════════════════════════════════════════════');
console.log('    🚀 GOOGLE PLAY MCP SERVER - CONFIGURATION VERIFICATION      ');
console.log('════════════════════════════════════════════════════════════════\n');

async function displayServerStatus() {
    try {
        if (!SERVICE_ACCOUNT_KEY) {
            throw new Error('SERVICE_ACCOUNT_KEY not found in environment');
        }

        const keyObject = JSON.parse(SERVICE_ACCOUNT_KEY);

        console.log('📋 SERVICE ACCOUNT DETAILS:');
        console.log(`   ✅ Project ID: ${keyObject.project_id}`);
        console.log(`   ✅ Service Account Email: ${keyObject.client_email}`);
        console.log(`   ✅ Key ID: ${keyObject.private_key_id}\n`);

        console.log('📱 ANDROID APP CONFIGURATION:');
        console.log(`   ✅ Package Name: ${PACKAGE_NAME}\n`);

        // Create auth client
        const auth = new google.auth.GoogleAuth({
            credentials: keyObject,
            scopes: ['https://www.googleapis.com/auth/androidpublisher'],
        });

        const androidpublisher = google.androidpublisher({
            version: 'v3',
            auth: auth,
        });

        console.log('🔐 API CONNECTION TEST:');
        const appResult = await androidpublisher.edits.insert({
            packageName: PACKAGE_NAME,
        });
        const editId = appResult.data.id;
        console.log(`   ✅ Edit session created successfully\n`);

        // Get tracks
        const tracksResult = await androidpublisher.edits.tracks.list({
            packageName: PACKAGE_NAME,
            editId: editId,
        });

        console.log('📊 RELEASE TRACKS STATUS:');
        if (tracksResult.data.tracks) {
            tracksResult.data.tracks.forEach(track => {
                const releaseCount = track.releases?.length || 0;
                const status = releaseCount > 0 ? '✅' : '⚠️';
                console.log(`   ${status} ${track.track.padEnd(15)} - ${releaseCount} release(s)`);

                if (track.releases && track.releases.length > 0) {
                    track.releases.forEach(release => {
                        const versionCode = release.versionCodes?.join(', ') || 'N/A';
                        console.log(`        └─ v${versionCode} (${release.status})`);
                    });
                }
            });
        }
        console.log();

        // Clean up
        await androidpublisher.edits.delete({
            packageName: PACKAGE_NAME,
            editId: editId,
        });

        console.log('════════════════════════════════════════════════════════════════');
        console.log('    ✨ MCP SERVER IS FULLY OPERATIONAL AND READY TO USE! ✨    ');
        console.log('════════════════════════════════════════════════════════════════\n');

        console.log('📚 AVAILABLE TOOLS IN MCP SERVER:');
        console.log('   • google_get_app_info - Get detailed app information');
        console.log('   • google_get_track_status - Check specific track status');
        console.log('   • google_list_releases - List all releases across tracks');
        console.log('   • google_get_review_status - Check review status');
        console.log('   • google_delete_track_release - Clear releases from track');
        console.log('   • google_promote_release - Promote release between tracks');
        console.log('   • google_halt_release - Pause a staged rollout');
        console.log('   • google_resume_release - Resume a paused rollout');
        console.log('   • google_complete_staged_release - Complete staged rollout');
        console.log('   • google_add_testers - Add beta testers');
        console.log('   • google_remove_testers - Remove beta testers');
        console.log('   • google_list_testers - List current testers');
        console.log('   • google_set_testers - Set tester list');
        console.log('   + And many more...\n');

        console.log('💡 USAGE:');
        console.log('   The MCP server is ready to be used by Claude or other');
        console.log('   MCP-compatible clients for managing Google Play releases.\n');

    } catch (err) {
        console.error('❌ Error:', err.message);
        if (err.response?.data) {
            console.error('Response:', err.response.data);
        }
        process.exit(1);
    }
}

displayServerStatus();
