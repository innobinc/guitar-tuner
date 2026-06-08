import re
import glob
import pathlib
import os

PROJECT = pathlib.Path("/tmp/guitar_tuner")

# AndroidManifest
manifest_path = PROJECT / "android/app/src/main/AndroidManifest.xml"
manifest = manifest_path.read_text()
if "RECORD_AUDIO" not in manifest:
    manifest = manifest.replace(
        "<application",
        '<uses-permission android:name="android.permission.RECORD_AUDIO"/>\n    <application'
    )
    manifest_path.write_text(manifest)
print("Manifest OK")

# app/build.gradle
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
print("app/build.gradle OK")

# Patch ALL flutter plugin build.gradle files (fixes flutter.xxx references)
pattern = os.path.expanduser("~/.pub-cache/hosted/pub.dev/*/android/build.gradle")
patched = 0
for f in glob.glob(pattern):
    content = pathlib.Path(f).read_text()
    if "flutter." in content:
        content = re.sub(r"flutter\.compileSdkVersion", "35", content)
        content = re.sub(r"flutter\.minSdkVersion", "21", content)
        content = re.sub(r"flutter\.targetSdkVersion", "35", content)
        content = re.sub(r"flutter\.ndkVersion", '"27.0.12077973"', content)
        pathlib.Path(f).write_text(content)
        print(f"Patched plugin: {f}")
        patched += 1
print(f"Patched {patched} plugin(s) total")
