# Define default shell
set shell := ["bash", "-c"]

# print list of commands
default:
    @just  --unsorted --list

# search and run command
run:
    @just  --choose

# 🧹 Clean the project
clean:
    echo "🧹 Cleaning project..."
    flutter clean
    just get

    cd ios
    echo 'Cleaning CocoaPods cache... 🧹'
    pod cache clean --all
    echo 'Removing Podfile.lock... 📝'
    rm Podfile.lock
    echo 'Removing .symlinks/ directory... 🗑️'
    rm -rf .symlinks/
    cd ..
    echo 'Cleaning Flutter project... 🧼'
    flutter clean
    echo 'Getting Flutter dependencies... 📦'
    flutter pub get
    cd ios
    echo 'Updating CocoaPods... 🚀'
    pod update
    echo 'Updating CocoaPods repository... 📡'
    pod repo update
    echo 'Installing CocoaPods dependencies with repo update... ⏳'
    pod install --repo-update
    echo 'Updating CocoaPods again... 🔄'
    pod update
    echo 'Installing CocoaPods dependencies... ⏳'
    pod install
    cd ..

# 📦 Get dependencies
get:
    echo "📦 Fetching dependencies..."
    flutter pub get

# 🔢 Automatically update build number in pubspec.yaml
update-version:
    echo "🔢 Updating version in pubspec.yaml..."
    path_to_pubspec="pubspec.yaml"
    current_version=$(awk '/^version:/ {print $2}' $path_to_pubspec)
    current_version_without_build=$(echo "$current_version" | sed 's/\+.*//')
    gitcount=$(git rev-list --count HEAD)
    new_version="$current_version_without_build+$gitcount"
    echo "🔄 Setting pubspec.yaml version from $current_version to $new_version"
    sed -i "" "s/version: $current_version/version: $new_version/g" $path_to_pubspec

# 🍏 Build iOS IPA with obfuscation
ipa:
    echo "🍏 Building iOS IPA with obfuscation..."
    flutter build ipa --obfuscate --split-debug-info=build/ios_debug_info

# 🤖 Build Android App Bundle with obfuscation
appbundle:
    echo "🤖 Building Android App Bundle with obfuscation..."
    flutter build appbundle --obfuscate --split-debug-info=build/android_debug_info

apk:
    echo "🤖 Building Android APK with obfuscation..."
    flutter build apk --split-per-abi --obfuscate --split-debug-info=build/android_debug_info

# 🚧 Build windiws app
windows:
    echo "🚧 Building Windows app..."
    dart run msix:create
    flutter build windows


# 🚀 Full process: Clean, update version, get dependencies, then build iOS & Android
build-all:
    echo "🚀 Starting full build process..."
    just clean
    just update-version
    just get
    just ipa
    just appbundle
    echo "✅ Build process complete!"


build:
    echo "🚀  Generating files"
    dart run build_runner build --delete-conflicting-outputs
    echo "✅  process complete!"

watch:
    echo "🚀  Watching files"
    dart run build_runner watch --delete-conflicting-outputs
    echo "✅  process complete!"

launcher_icon:
	dart pub run flutter_launcher_icons:main

splash_screen:
	dart pub run flutter_native_splash:create

gen_l10n:
	flutter gen-l10n

brand:
    @echo "⚡ Branding Project Grapha..."
    @echo "⚡ Branding Grapha Launcher Icons..."
    dart pub run flutter_launcher_icons:main
    @echo "⚡ Branding Grapha Splash Screen..."
    dart pub run flutter_native_splash:create
    @echo "⚡ Branding Done!"