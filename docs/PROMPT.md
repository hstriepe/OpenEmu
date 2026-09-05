# OpenEmu


Set all deployment targets to versions 12.0

Fix full build:
 xcodebuild -workspace OpenEmu.xcworkspace -scheme "OpenEmu" -configuration Release

Do a release build, and sign all elements with my signature D6WY385Q4D. Move to ./release

What is the current diference between the standard and EopenEmu-metal workspaces?

Move bundle roots and signing info into a an xcode config file.
Config.xcconfig (includes both:)
  ├── CodeSignDefault.xcconfig
  ├── AppBundleAndSigning.xcconfig
  └── CodeSign.xcconfig? (optional, user-specific)

I have forked this repo at
   https://github.com/hstriepe/OpenEmu.git

Add fetch and push to this url, commit, and push. Only push an Config.xcconfig template file with comments.
