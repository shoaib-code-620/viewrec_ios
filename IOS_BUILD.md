# Running ViewRec on iPhone

The app is one Flutter project: the same code builds the Android app and the iOS app.
Android (APK) is built on Windows. **iOS can only be built on a Mac**, so we use a cloud Mac.

## Step 1 - prove it compiles for iOS (free, no Apple account)

1. Put this folder in a Git repository on GitHub (private is fine).
2. GitHub -> **Actions** -> **iOS build** -> **Run workflow**. (The file is `.github/workflows/ios-build.yml`.)
3. Wait about 15 minutes. A green tick means the iOS app builds. The download is an *unsigned* app: it proves the
   build works but cannot be installed on a phone.

Alternative: connect the repository to Codemagic and run the **ios-check** workflow in `codemagic.yaml`.

## Step 1b - put it on YOUR iPhone with a free Apple ID (no paid account)

The "iOS build" run also produces `ViewRec-unsigned-ipa` (an unsigned `ViewRec-unsigned.ipa`). A free tool can sign it
with your own Apple ID and install it over a USB cable. This is unofficial, and the app **stops opening after 7 days**
(repeat the install to renew it). Good for testing on your own phone, not for giving to customers.

1. On GitHub: Actions -> the finished "iOS build" run -> Artifacts -> download `ViewRec-unsigned-ipa` and unzip it.
2. On this Windows PC install **iTunes** (the Apple website version, not the Microsoft Store one) and **Sideloadly**
   (https://sideloadly.io).
3. On the iPhone: connect by USB and tap "Trust". Settings -> Privacy & Security -> turn on **Developer Mode** (iOS 16+).
4. In Sideloadly: choose the iPhone, drag in `ViewRec-unsigned.ipa`, enter your Apple ID, press Start.
5. On the iPhone: Settings -> General -> VPN & Device Management -> trust your Apple ID. Open ViewRec.

Use an Apple ID you are comfortable with for this (a spare one is wise), because you type its password into a third-party tool.

## Step 2 - install it on iPhones (needs an Apple Developer account)

Apple only lets apps run on real iPhones when they are signed by a paid developer account.

1. Join the **Apple Developer Program** (about $99 per year): https://developer.apple.com/programs/
2. In App Store Connect, create an app with bundle ID `com.viewrec.viewrec` and name "ViewRec".
3. In Codemagic: Teams -> Integrations -> **App Store Connect** -> add an API key; name it `ViewRec-AppStoreConnect`.
4. Run the **ios-testflight** workflow. It signs the app and uploads it to **TestFlight**.
5. On the iPhone, install the free **TestFlight** app and accept the invitation. The app installs like any other.

## Things that already work on iOS in this project

- Camera and microphone permission texts (`ios/Runner/Info.plist`).
- App icon (all sizes), app name "ViewRec", minimum iOS 15.
- Video upload labels iPhone recordings (`.mov`) correctly.
- Haptics, themes, animations and the water bar are plain Flutter and run on iOS too.

## Things to check on a real iPhone (cannot be tested on Windows)

- Recording and upload on a real device (camera, microphone, file size).
- That the glass blur on the tab bar stays smooth on older iPhones.
- If the real backend uses plain `http://`, iOS blocks it. Use `https://`.
