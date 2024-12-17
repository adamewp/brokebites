#!/bin/sh

# Flutter version management
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git
export PATH="$PATH:`pwd`/flutter/bin"
flutter precache --ios
flutter pub get

# CocoaPods setup
echo "Setting up CocoaPods..."
sudo gem install cocoapods
cd ios
pod install

# Debug information
echo "Debugging information:"
flutter --version
pod --version 