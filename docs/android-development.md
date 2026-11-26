# Android development on macOS

## Where to declare dependencies

| Dependency | Where it belongs |
| --- | --- |
| Shared macOS command-line tools | Dotfiles `Brewfile`. Use `brew bundle install --file=Brewfile --no-upgrade` to add missing tools. |
| Language runtimes | Dotfiles mise config for shared defaults, or project mise config when the project needs a specific version. |
| Android platform, Build Tools, emulator, and images | Android SDK Manager, using the package IDs listed below. |
| Android build plugins and app libraries | The project's Gradle files and wrapper. If an AAR comes directly from a vendor, keep its download URL, version, and checksum in the project. |
| SDK path overrides and emulator data | Local shell configuration and the SDK's default per-user directories. |

For each new toolchain, record the install source, versions or package IDs,
configuration location, and the command that verified it.

## Set up the SDK on Apple Silicon

On a fresh Mac, install Android Studio and run its setup wizard. In its SDK
Manager, install **Android SDK Command-line Tools (latest)** and **Android SDK
Platform-Tools** if they are missing. Use `~/Library/Android/sdk` as the SDK
location. The dotfiles already export `ANDROID_HOME` and expose `adb` and
`emulator` on `PATH`. The commands below use full SDK paths to select the tools
from that installation. Keep SDK path overrides in `~/.zshrc.local`.
If the shell also exports `ANDROID_SDK_ROOT`, keep both paths aligned.
[Android Studio installation](https://developer.android.com/studio/install) ·
[Android environment variables](https://developer.android.com/tools/variables)

The setup used Android Studio's bundled Java 17. Select the JDK version your
project requires when you build. Keeping the selection in the current shell
lets other projects use their own JDK.

```sh
export ANDROID_HOME="$HOME/Library/Android/sdk"
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
sdkmanager="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

"$JAVA_HOME/bin/java" -version
"$sdkmanager" --sdk_root="$ANDROID_HOME" --install \
  'emulator' \
  'platforms;android-36' \
  'build-tools;36.0.0' \
  'system-images;android-36;google_apis;arm64-v8a'
"$sdkmanager" --sdk_root="$ANDROID_HOME" --list_installed
```

If the installer prompts for licenses, review them interactively with
`"$sdkmanager" --sdk_root="$ANDROID_HOME" --licenses`, then retry the install.
Select the platform from the project's `compileSdk` and the Build Tools from
the project's build configuration or Android Gradle Plugin requirements. The
ARM64 image in this example runs Android 16 on Apple Silicon.
[SDK Manager commands](https://developer.android.com/tools/sdkmanager) ·
[Android Gradle Plugin 9.2 compatibility](https://developer.android.com/build/releases/agp-9-2-0-release-notes)

### Installation record for 2026-11-25

| SDK package | Installed version | Action |
| --- | --- | --- |
| `emulator` | 37.3.10 | Upgraded from 33.1.24 |
| `platforms;android-36` | Revision 2 | Installed |
| `build-tools;36.0.0` | 36.0.0 | Installed |
| `system-images;android-36;google_apis;arm64-v8a` | Revision 7 | Installed |
| `platform-tools` | 34.0.5 | Reused |
| `cmdline-tools;latest` | 12.0 | Reused |

The bundled JDK was 17.0.7 and was already available. The `emulator`,
`platform-tools`, and `cmdline-tools;latest` package IDs track release channels.
SDK Manager can also return newer revisions for the same platform or image ID.
Use the table to compare the installed versions after setup.

## Create and verify a virtual device

Create the profile once. Choose the default if prompted for a custom hardware
profile. This example uses a Pixel 7, the Google APIs ARM64 image, and port 5564.
The virtual device's configuration and data are stored
under `~/.android/avd` by default. [AVD Manager](https://developer.android.com/tools/avdmanager) ·
[Emulator command line](https://developer.android.com/studio/run/emulator-commandline)

```sh
"$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd \
  --name Dev_Pixel_7_API_36 \
  --package 'system-images;android-36;google_apis;arm64-v8a' \
  --device pixel_7
"$ANDROID_HOME/emulator/emulator" -list-avds
"$ANDROID_HOME/emulator/emulator" -avd Dev_Pixel_7_API_36 -port 5564
```

From a second terminal, check that `sys.boot_completed` returns `1` and that the
SDK property returns `36`. Set `apk` to an existing debug APK path before running
the install command. Use the app's launcher icon to check startup. When you need
a fresh APK, use the project's Gradle wrapper and build instructions.

```sh
adb devices -l
adb -s emulator-5564 shell getprop sys.boot_completed
adb -s emulator-5564 shell getprop ro.build.version.sdk
apk=path/to/app-debug.apk
adb -s emulator-5564 install -r "$apk"
```

The setup was verified by booting the API 36 ARM64 image, installing an
existing debug APK, and confirming its launcher activity was in the foreground.

### If the emulator closes during startup

The first launch with automatic graphics exited after boot and logged a
graphics buffer error. To retry with software rendering and a cold boot, run
the emulator with these flags. [Emulator graphics modes](https://developer.android.com/studio/run/emulator-acceleration)

```sh
"$ANDROID_HOME/emulator/emulator" -avd Dev_Pixel_7_API_36 -port 5564 \
  -gpu software -no-snapshot-load
```
