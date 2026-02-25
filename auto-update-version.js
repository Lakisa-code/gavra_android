#!/usr/bin/env node

/**
 * 🤖 AUTOMATSKO AŽURIRANJE VERZIJE U SUPABASE
 * 
 * Korišćenje:
 *   node auto-update-version.js            # Proveri najnoviju verziju na Google Play i ažuriraj Supabase
 *   node auto-update-version.js --force    # Ažuriraj bez provere (koristi verziju iz pubspec.yaml)
 * 
 * Proces:
 *   1. Pročita Google Play Console API da proveri najnoviju LIVE verziju
 *   2. Uporedi sa trenutnom verzijom u Supabase app_settings
 *   3. Ako je nova verzija dostupna, automatski ažurira latest_version
 *   4. Opciono: Postavi min_version za force update
 */

require('dotenv').config({ path: './google-play-mcp/.env' });
const { google } = require('googleapis');
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const yaml = require('js-yaml');

// Configuration
const PACKAGE_NAME = 'com.gavra013.gavra_android';
const SERVICE_ACCOUNT_KEY = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Parse command line arguments
const args = process.argv.slice(2);
const isForceUpdate = args.includes('--force');
const isMinVersionUpdate = args.includes('--force-all'); // Force update (min_version = latest_version)

// Set up module resolution for google-play-mcp dependencies
require.main.paths.push(require('path').resolve('./google-play-mcp/node_modules'));

console.log('🤖 Auto Update Version Script\n');

async function main() {
    try {
        // 1. Get current version from Supabase
        console.log('📡 Connecting to Supabase...');
        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

        const { data: settings, error: fetchError } = await supabase
            .from('app_settings')
            .select('min_version, latest_version')
            .eq('id', 'global')
            .single();

        if (fetchError) throw fetchError;

        console.log(`✅ Current Supabase versions:`);
        console.log(`   Min version: ${settings.min_version || 'not set'}`);
        console.log(`   Latest version: ${settings.latest_version || 'not set'}\n`);

        let newVersion;

        if (isForceUpdate) {
            // Read version from pubspec.yaml
            console.log('📄 Reading version from pubspec.yaml...');
            const pubspec = yaml.load(fs.readFileSync('./pubspec.yaml', 'utf8'));
            newVersion = pubspec.version.split('+')[0]; // Extract version without build number
            console.log(`✅ Version from pubspec: ${newVersion}\n`);
        } else {
            // 2. Get latest PRODUCTION version from Google Play
            console.log('🔍 Checking Google Play Console...');

            if (!SERVICE_ACCOUNT_KEY) {
                throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT_KEY not found in environment');
            }

            const keyObject = JSON.parse(SERVICE_ACCOUNT_KEY);
            const auth = new google.auth.GoogleAuth({
                credentials: keyObject,
                scopes: ['https://www.googleapis.com/auth/androidpublisher'],
            });

            const androidpublisher = google.androidpublisher({
                version: 'v3',
                auth: await auth.getClient(),
            });

            // Get production track releases
            const { data: editResponse } = await androidpublisher.edits.insert({
                packageName: PACKAGE_NAME,
            });
            const editId = editResponse.id;

            const { data: track } = await androidpublisher.edits.tracks.get({
                packageName: PACKAGE_NAME,
                editId: editId,
                track: 'production',
            });

            // Find the latest completed release
            const completedRelease = track.releases?.find(r =>
                r.status === 'completed' || r.status === 'inProgress'
            );

            if (!completedRelease) {
                throw new Error('No completed production release found on Google Play');
            }

            newVersion = completedRelease.name || 'Unknown';
            const versionCodes = completedRelease.versionCodes || [];

            console.log(`✅ Google Play production version: ${newVersion}`);
            console.log(`   Version codes: ${versionCodes.join(', ')}`);
            console.log(`   Status: ${completedRelease.status}\n`);

            // Clean up edit
            await androidpublisher.edits.delete({
                packageName: PACKAGE_NAME,
                editId: editId,
            });
        }

        // 3. Compare versions
        if (newVersion === settings.latest_version && !isMinVersionUpdate) {
            console.log('✅ Supabase is already up to date. No changes needed.');
            return;
        }

        // 4. Update Supabase
        console.log(`🔄 Updating app_settings in Supabase...`);

        const updateData = {
            latest_version: newVersion,
            updated_at: new Date().toISOString(),
        };

        if (isMinVersionUpdate) {
            updateData.min_version = newVersion;
            console.log(`⚠️  Force update enabled: min_version will also be set to ${newVersion}`);
        }

        const { error: updateError } = await supabase
            .from('app_settings')
            .update(updateData)
            .eq('id', 'global');

        if (updateError) throw updateError;

        console.log(`\n✅ SUCCESS! Version updated in Supabase:`);
        if (isMinVersionUpdate) {
            console.log(`   Min version: ${settings.min_version} → ${newVersion} (FORCE UPDATE)`);
        }
        console.log(`   Latest version: ${settings.latest_version} → ${newVersion}`);
        console.log(`\n🔔 All users will receive update notification in real-time!`);

    } catch (error) {
        console.error('\n❌ ERROR:', error.message);
        process.exit(1);
    }
}

main();
