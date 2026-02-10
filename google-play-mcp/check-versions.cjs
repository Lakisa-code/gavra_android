const { google } = require("googleapis");

const keyFile = "../../google-play-key.json";
const packageName = "com.gavra013.gavra_android";

async function checkVersions() {
    const auth = new google.auth.GoogleAuth({
        keyFile: keyFile,
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });

    const androidpublisher = google.androidpublisher("v3");

    try {
        // Kreiramo edit
        const editRes = await androidpublisher.edits.insert({
            auth: auth,
            packageName: packageName,
        });

        const editId = editRes.data.id;
        console.log(`\n✅ Edit ID: ${editId}\n`);

        // Dobijamo sve track-ove
        const tracksResponse = await androidpublisher.edits.tracks.list({
            auth: auth,
            packageName: packageName,
            editId: editId,
        });

        console.log("📱 VERZIJE NA GOOGLE PLAY STORE:\n");

        if (tracksResponse.data.tracks) {
            for (const track of tracksResponse.data.tracks) {
                console.log(`\n🔷 Track: ${track.track.toUpperCase()}`);

                if (track.releases && track.releases.length > 0) {
                    for (const release of track.releases) {
                        const versionCodes = release.versionCodes ? release.versionCodes.join(", ") : "N/A";
                        const versionName = release.name || "N/A";
                        const status = release.status;
                        console.log(`   📌 Version Code: ${versionCodes}`);
                        console.log(`   📌 Version Name: ${versionName}`);
                        console.log(`   📌 Status: ${status}`);
                        console.log(`   📌 Release Notes: ${release.releaseNotes && release.releaseNotes[0] ? release.releaseNotes[0].text : "Nema"}`);
                    }
                } else {
                    console.log("   ❌ Nema izdanja");
                }
            }
        }

        console.log("\n");

        // Zatvori edit bez sačuvavanja
        await androidpublisher.edits.delete({
            auth: auth,
            packageName: packageName,
            editId: editId,
        });

        console.log("✨ Pregled završen\n");

    } catch (error) {
        console.error("❌ Greška:", error.message || error);
        process.exit(1);
    }
}

checkVersions();
