#!/usr/bin/env node

require('dotenv').config();
const { google } = require('googleapis');

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.gavra013.gavra_android';
const SERVICE_ACCOUNT_KEY = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;

console.log('🔍 Testing Google Play Console API...\n');

async function testGooglePlayAPI() {
    try {
        if (!SERVICE_ACCOUNT_KEY) {
            throw new Error('SERVICE_ACCOUNT_KEY not found in environment');
        }

        const keyObject = JSON.parse(SERVICE_ACCOUNT_KEY);
        console.log('✅ Service account key loaded');
        console.log(`   Project: ${keyObject.project_id}`);
        console.log(`   Client: ${keyObject.client_email}`);
        console.log(`   Package: ${PACKAGE_NAME}\n`);

        // Create auth client
        const auth = new google.auth.GoogleAuth({
            credentials: keyObject,
            scopes: ['https://www.googleapis.com/auth/androidpublisher'],
        });

        const androidpublisher = google.androidpublisher({
            version: 'v3',
            auth: auth,
        });

        console.log('🔐 Authentication initialized\n');

        // Test 1: Get app info
        console.log('📱 Test 1: Getting app details...');
        try {
            const appResult = await androidpublisher.edits.insert({
                packageName: PACKAGE_NAME,
            });
            const editId = appResult.data.id;
            console.log(`✅ Edit session created: ${editId}\n`);

            // Test 2: Get tracks
            console.log('📊 Test 2: Listing tracks...');
            const tracksResult = await androidpublisher.edits.tracks.list({
                packageName: PACKAGE_NAME,
                editId: editId,
            });

            if (tracksResult.data.tracks) {
                console.log(`✅ Found ${tracksResult.data.tracks.length} tracks:`);
                tracksResult.data.tracks.forEach(track => {
                    console.log(`   - ${track.track}`);
                    if (track.releases && track.releases.length > 0) {
                        track.releases.forEach(release => {
                            console.log(`     Release: ${release.versionCodes?.join(', ') || 'N/A'} (${release.status})`);
                        });
                    }
                });
            }
            console.log();

            // Test 3: Get app status
            console.log('📈 Test 3: Checking app status...');
            try {
                const statusResult = await androidpublisher.edits.validate({
                    packageName: PACKAGE_NAME,
                    editId: editId,
                });
                console.log('✅ Edit validation passed\n');
            } catch (e) {
                console.log(`⚠️ Edit validation: ${e.message}\n`);
            }

            // Clean up: delete the edit
            await androidpublisher.edits.delete({
                packageName: PACKAGE_NAME,
                editId: editId,
            });
            console.log('🧹 Cleaned up edit session\n');

        } catch (err) {
            console.error('❌ API Error:', err.message);
            if (err.errors) {
                err.errors.forEach(e => console.error(`   - ${e.message}`));
            }
            console.log();
        }

        console.log('✨ All tests completed!');

    } catch (err) {
        console.error('❌ Fatal Error:', err.message);
        process.exit(1);
    }
}

testGooglePlayAPI();
