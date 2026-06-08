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
# minSdk -> 24 (flutter_sound 9.28 requires API 24+)
g = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", g)
g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", g)
g = re.sub(r"minSdk\s+flutter\.minSdkVersion", "minSdk 24", g)
# compileSdk -> 35
g = re.sub(r"compileSdkVersion\s+flutter\.compileSdkVersion", "compileSdkVersion 35", g)
g = re.sub(r"compileSdk\s*=\s*flutter\.compileSdkVersion", "compileSdk = 35", g)
g = re.sub(r"compileSdk\s+flutter\.compileSdkVersion", "compileSdk 35", g)
# targetSdk -> 35
g = re.sub(r"targetSdkVersion\s+flutter\.targetSdkVersion", "targetSdkVersion 35", g)
g = re.sub(r"targetSdk\s*=\s*flutter\.targetSdkVersion", "targetSdk = 35", g)
g = re.sub(r"targetSdk\s+flutter\.targetSdkVersion", "targetSdk 35", g)
# Remove ndkVersion
g = re.sub(r"[ \t]*ndkVersion[^\n]*\n", "", g)
# Java 11
g = g.replace("sourceCompatibility JavaVersion.VERSION_1_8", "sourceCompatibility JavaVersion.VERSION_11")
g = g.replace("targetCompatibility JavaVersion.VERSION_1_8", "targetCompatibility JavaVersion.VERSION_11")
g = g.replace("jvmTarget = '1.8'", "jvmTarget = '11'")
gp.write_text(g)
print(f"app/build.gradle OK:\n{gp.read_text()}")

# Patch ALL plugin build.gradle files (recursive)
pub_cache = os.path.expanduser("~/.pub-cache/hosted/pub.dev")
all_gradle = glob.glob(os.path.join(pub_cache, "**", "build.gradle"), recursive=True)
print(f"\nFound {len(all_gradle)} build.gradle file(s) in pub-cache")

patched = 0
for f in all_gradle:
    content = pathlib.Path(f).read_text()
    if "flutter." not in content:
        continue
    original = content
    content = re.sub(r"flutter\.compileSdkVersion", "35", content)
    content = re.sub(r"flutter\.minSdkVersion", "24", content)
    content = re.sub(r"flutter\.targetSdkVersion", "35", content)
    content = re.sub(r"flutter\.ndkVersion", '"27.0.12077973"', content)
    if content != original:
        pathlib.Path(f).write_text(content)
        print(f"  Patched: {f}")
        patched += 1

print(f"\nPatched {patched} plugin file(s)")
