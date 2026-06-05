import re
import pathlib

PROJECT = pathlib.Path("/tmp/guitar_tuner")

# AndroidManifest
manifest = (PROJECT / "android/app/src/main/AndroidManifest.xml").read_text()
if "RECORD_AUDIO" not in manifest:
    manifest = manifest.replace(
        "<application",
        '<uses-permission android:name="android.permission.RECORD_AUDIO"/>\n    <application'
    )
    (PROJECT / "android/app/src/main/AndroidManifest.xml").write_text(manifest)
print("Manifest OK")

# build.gradle
gp = PROJECT / "android/app/build.gradle"
g = gp.read_text()
g = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 21", g)
g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 21", g)
g = re.sub(r"minSdk\s+flutter\.minSdkVersion", "minSdk 21", g)
g = re.sub(r"[ \t]*ndkVersion[^\n]*\n", "", g)
g = g.replace("sourceCompatibility JavaVersion.VERSION_1_8", "sourceCompatibility JavaVersion.VERSION_11")
g = g.replace("targetCompatibility JavaVersion.VERSION_1_8", "targetCompatibility JavaVersion.VERSION_11")
g = g.replace("jvmTarget = '1.8'", "jvmTarget = '11'")
gp.write_text(g)
print("build.gradle OK")
print(gp.read_text())
