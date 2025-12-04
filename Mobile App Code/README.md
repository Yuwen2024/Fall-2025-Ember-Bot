# Ember Bot Mobile App

## Setting up the development eivironment

1. Downlowd Visual Studio Code.
2. Download and install Xcode.
3. run xcode-select –install
4. Install the Flutter extension in VS Code.
5. Open Command Palette in VS Code and type flutter. Choose Flutter: Run Flutter Doctor
6. An error will show up, choose Download SDK
7. Create a folder called flutter_sdk anywhere in the popup window, VS Code will clone the SDK
8. Add Flutter to system PATH: create a file ~/.zshenv if it does not exixt. Add “export PATH=$HOME/development/flutter/bin:$PATH” to the file. Replace “development/flutter/” with the flutter SDK path just entered. Please see https://docs.flutter.dev/install/with-vs-code.
9. Close all VS Code windows and terminal windows
10. Reopen terminal, type “flutter –version” to verify Flutter SDK is installed
11. Run sudo softwareupdate --install-rosetta --agree-to-license in terminal to install  Rosetta 2
12. Run sudo sh -c 'xcode-select -s /Applications/Xcode.app/Contents/Developer && xcodebuild -runFirstLaunch' to configure Xcode
13. Run sudo xcodebuild -license to sign the Xcode license agreement, type agree and hit enter upon prompt
14. Run xcodebuild -downloadPlatform iOS to install iOS simulator on Mac
15. Use open -a Simulator to open iOS simulator
16. Run flutter doctor to verity Flutter is installed properly
17. Run sudo gem install cocoapods to install cocoapods
18. Add export PATH=$HOME/.gem/bin:$PATH to the ~/.zshenv file. Refer to https://docs.flutter.dev/get-started/install/macos/mobile-ios#add-flutter-to-your-path for more information on setting up iOS development with Flutter on Mac

## Execute the code

Warning: Make sure you have set up the developer's mode on your iOS devices.

1. Open the Flutter project's Xcode target with
       open ios/Runner.xcworkspace
2. Select the 'Runner' project in the navigator then the 'Runner' target
   in the project settings
3. Make sure a 'Development Team' is selected under Signing & Capabilities > Team. 
   You may need to:
       - Log in with your Apple ID in Xcode first
       - Ensure you have a valid unique Bundle ID
       - Register your device with your Apple Developer Account
       - Let Xcode automatically provision a profile for your app
4. Build or run your project again
5. Trust your newly created Development Certificate on your iOS device
   via Settings > General > Device Management > [your new certificate] > Trust

For more information, please visit:
  https://developer.apple.com/library/content/documentation/IDEs/Conceptual/
  AppDistributionGuide/MaintainingCertificates/MaintainingCertificates.html

Or run on an iOS simulator without code signing

flutter build ios

flutter install <target device name>


