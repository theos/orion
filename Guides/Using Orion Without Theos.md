# Orion without Theos
 
## Preface
This guide assumes you have an iOS toolchain installed along with headers and frameworks. If you don’t please follow the [installation instructions](https://github.com/theos/theos/wiki/Installation) for Theos and follow the [Getting Started](https://orion.theos.dev/getting-started.html) guide instead.
 
This guide will show you how to make the same tweak as the one in the Getting Started guide.
 
To follow along, you will require the following things:
- iOS toolchain with headers and frameworks
   - Clone `https://github.com/theos/lib.git` and switch to branch orion-support by `git clone https://github.com/theos/lib.git && git checkout orion-support` and add that folder to your list of framework folders
- A jailbroken iOOS device
- The target app (in this tutorial, VLC for iOS) installed on your iOS device.
 
Note that this guide will use the format
<pre>&lt;current directory&gt $ <span class="inp">&lt;command&gt;</span></pre>
for all shell commands. User input will be in <code><span class="inp">red</span></code>.
 
## Setup
Orion is currently in beta, so you need to take a few additional steps to use it:
 
1. Add the Theos repo (https://repo.theos.dev/) to your jailbroken device’s package manager, and install the Orion package (pick iOS 12-13 or iOS 14 depending on your version).
2. Clone Orion, get submodules, and compile by running `git clone https://github.com/theos/orion.git && cd orion && git submodule update --init && swift build`. Orion will be compiled to `.build/[your computer’s arch]/orion` - write down that path for later.
 
## Initializing an Orion Tweak
To get started create the directory you want for your tweak, for me I’m naming my tweak “mytweak” and creating the folder. From there you need to create the following folder structure:
<pre>
- control
- mytweak.plist
- Sources
   - mytweak
       - mytweak.x.swift
   - mytweakC
       - Tweak.m
       - include
           - Tweak.h
           - module.modulemap
- .out
   - arm64e
       - filemap.json
   - arm64
       - filemap.json
</pre>
The number of files might seem daunting at first, but each one has a specific purpose which you'll quickly come to learn. Here's a brief description:
 
- `mytweak.plist`: This is the [CydiaSubstrate bundle filter](https://iphonedevwiki.net/index.php/Cydia_Substrate#Filters) for your tweak. It tells CydiaSubstrate (or an equivalent tweak loader) which processes your tweak should be loaded into.
- `control`:  The Debian [control file](https://iphonedevwiki.net/index.php/Packaging#Control_file) which describes your tweak's .deb package to package managers.
- `Sources`: This is where your source code goes. C/Objective-C files (`.m`, `.mm`, `.c`, `.cpp`) go in the folder with the `C` suffix, and Swift/Orion files (`.swift`, `.x.swift`) go into the folder without the suffix.
- `.out`: This is where the compiler will put all the files it generates later on.
- `.out/*/filemap.json`: This is instructions for the Swift compiler on where to place the files it generates.
 
Normally Theos will generate all of these files with the default contents, but as we're not using Theos we have to set the default contents ourselves.
 
### Control:
```
Package: com.yourcompany.mytweak
Name: mytweak
Version: 0.0.1
Architecture: iphoneos-arm
Description: An awesome Orion tweak!
Maintainer: Juliette
Author: Juliette
Section: Tweaks
Depends: dev.theos.orion (= 0.9.5), firmware (>= 12.2)
```
 
### mytweak.plist
```plist
{ Filter = { Bundles = ( "org.videolan.vlc-ios" ); }; }
```
 
### Sources/mytweakC/Tweak.m
```objc
#import <Orion/Orion.h>
 
__attribute__((constructor)) static void init() {
   // Initialize Orion - do not remove this line.
   orion_init();
   // Custom initialization code goes here.
}
```
 
### Sources/mytweakC/include/module.modulemap
```modulemap
module mytweakC {
       umbrella "."
       export *
}
```
 
### .out/arm64/filemap.json
```json
{
 ".out/mytweak.xc.swift": {
   "object": ".out/arm64/mytweak.xc.swift.o",
   "dependencies": ".out/arm64/mytweak.xc.swift.Td",
   "swift-dependencies": ".out/arm64/mytest.xc.swift.swiftdeps"
 },
 "Sources/mytweak/mytweak.x.swift": {
   "object": ".out/arm64/mytweak.x.swift.o",
   "dependencies": ".out/arm64e/mytweak.x.swift.Td",
   "swift-dependencies": ".out/arm64/mytweak.x.swift.swiftdeps"
 },
 "": {
   "dependencies": ".out/arm64e/master.Td",
   "swift-dependencies": ".out/arm64/master.swiftdeps"
 }
}
 
```
 
### .out/arm64e/filemap.json
```json
{
 ".out/mytweak.xc.swift": {
   "object": ".out/arm64e/mytweak.xc.swift.o",
   "dependencies": ".out/arm64e/mytweak.xc.swift.Td",
   "swift-dependencies": ".out/arm64e/mytest.xc.swift.swiftdeps"
 },
 "Sources/mytweak/mytweak.x.swift": {
   "object": ".out/arm64e/mytweak.x.swift.o",
   "dependencies": ".out/arm64e/mytweak.x.swift.Td",
   "swift-dependencies": ".out/arm64e/mytweak.x.swift.swiftdeps"
 },
 "": {
   "dependencies": ".out/arm64e/master.Td",
   "swift-dependencies": ".out/arm64e/master.swiftdeps"
 }
}
 
```
 
 
## Editing your Tweak
Orion uses a preprocessor, and you will have to pass all `.x.swift` files through this preprocessor while building. All hooks **must** therefore go into files with a `.x.swift` extension. The structure we have has `Tweak.x.swift`, so we'll start by editing this.
 
Open up your favorite text editor and delete the contents and replace it with the following:
```swift
// 1
import Orion
import UIKit
 
// 2
class LabelHook: ClassHook<UILabel> {
}
```
 
Here's an explanation of the important lines:
 
1. We first import Orion's APIs into the Swift file using `import Orion`. We also import `UIKit` since we need the compiler to know about the `UILabel` class.
2. Next, we declare a **hook**. A hook is the fundamental unit of Orion tweaks. It is used to modify the behavior of existing code. A `ClassHook` allows you to replace methods on a "target" class (in this case, `UILabel`) by writing own implementations.
 
Next, insert the following code between the curly braces (right before the last line):
 
```swift
// 1
func setText(_ text: String) {
   // 2
   orig.setText(
       // 3
       text.uppercased().replacingOccurrences(of: " ", with: "👏")
   )
}
```
 
Here's a breakdown of this code:
 
1. In brief, any function declared within a class hook replaces ("swizzles") the implementation of the Objective-C function with the same name in the target class. In this case, we are therefore changing the behavior of the `setText` function of `UILabel`, which is called whenever the [`text` property](https://developer.apple.com/documentation/uikit/uilabel/1620538-text) is set. In Objective-C land, this is called a [setter](https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaCore/AccessorMethod.html).
2. In our replaced implementation, we call back to the original implementation of `setText` but we replace the argument with our own. The original implementations of our swizzled methods can be accessed via `orig` as shown in the above code.
3. The replaced argument is the text in all caps with all spaces replaced with the 👏 emoji.
 
All in all, your code should look like this:
 
```swift
import Orion
import UIKit
 
class LabelHook: ClassHook<UILabel> {
   func setText(_ text: String) {
       orig.setText(
           text.uppercased().replacingOccurrences(of: " ", with: "👏")
       )
   }
}
```
 
That's all for the code! Now let's get ready to build the package!
 
## Stage one
In order to create a tweak with Orion it takes multiple stages, the first stage is running the preprocessor on `Sources/mytweak/mytweak.x.swift` by running:
<pre>
~/mytweak $ <span class="inp">[orion executable path] --backend Substrate Sources/mytweak/mytweak.x.swift -o .out/mytweak.xc.swift</span>
</pre>
 
## Stage two part one
Now that we have have the preprocessed version of mytweak.x.swift, let's compile it for ARM64.
<pre>
~/mytweak $ <span class="inp">swiftc -c [your iOS includes]  -Xfrontend -color-diagnostics -Xcc -fcolor-diagnostics -Xcc -DTARGET_IPHONE=1 -Xcc -O0 -Xcc -Wall -Xcc -ggdb -Xcc -Wno-unused-command-line-argument -Xcc -Qunused-arguments -Xcc -Werror -Xcc -isysroot -Xcc "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk" -Xcc -target -Xcc arm64-apple-ios12.2 -Xcc -fobjc-arc -Xcc -ISources/mytweakC/include -Xcc -DDEBUG -Xcc -O0 -Xcc -DTHEOS_INSTANCE_NAME="\"mytweak\"" -Xcc -fmodules -Xcc -fcxx-modules -Xcc -fmodule-name=mytweak  -Xcc -fmodules-prune-interval=86400 -Xcc -arch -Xcc arm64 -Xcc -stdlib=libc++ -Xcc [your iOS frameworks includes] -DTHEOS_SWIFT -DTARGET_IPHONE  -module-name mytweak -g  -swift-version 5 -sdk "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk"  -resource-dir /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/../lib/swift -ISources/mytweakC/include -DDEBUG -Onone -incremental -target arm64-apple-ios12.2 -output-file-map .out/filemap.json -emit-objc-header-path .out/arm64/mytweak-Swift.h -emit-dependencies -emit-module-path .out/arm64/mytweak.swiftmodule Sources/mytweak/mytweak.x.swift .out/mytweak.xc.swift</span></pre>
 
For example, if I had Dragon installed and had `https://github.com/theos/lib.git` installed at `$HOME/.dragon/vendor/lib`, I would run:
<pre>
~/mytweak $ <span class="inp">swiftc -c -I$HOME/.dragon/include -I$HOME/.dragon/vendor/include -I$HOME/.dragon/include/_fallback -Xfrontend -color-diagnostics -Xcc -fcolor-diagnostics -Xcc -DTARGET_IPHONE=1 -Xcc -O0 -Xcc -Wall -Xcc -ggdb -Xcc -Wno-unused-command-line-argument -Xcc -Qunused-arguments -Xcc -Werror -Xcc -isysroot -Xcc "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk" -Xcc -target -Xcc arm64-apple-ios12.2 -Xcc -fobjc-arc -Xcc -ISources/mytweakC/include -Xcc -DDEBUG -Xcc -O0 -Xcc -DTHEOS_INSTANCE_NAME="\"test\"" -Xcc -fmodules -Xcc -fcxx-modules -Xcc -fmodule-name=test  -Xcc -fmodules-prune-interval=86400 -Xcc -arch -Xcc arm64 -Xcc -stdlib=libc++ -Xcc -F$HOME/.dragon/lib -Xcc -F$HOME/.dragon/vendor/lib -DTHEOS_SWIFT -DTARGET_IPHONE  -module-name test -g -F$HOME/.dragon/lib -F$HOME/.dragon/vendor/lib -swift-version 5 -sdk "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk"  -resource-dir /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/../lib/swift  -ISources/mytweakC/include -DDEBUG -Onone -incremental -target arm64-apple-ios12.2 -output-file-map .out/arm64/filemap.json -emit-objc-header-path .out/arm64/mytweak-Swift.h -emit-dependencies Sources/mytweak/mytweak.x.swift .out/mytweak.xc.swift</span></pre>
 
## Stage two part two
In the previous part, we compiled our tweak for ARM64, now we need to compile it for ARM64e. You can do this by running:
<pre>
~/mytweak $ <span class="inp">swiftc -c [your iOS includes]  -Xfrontend -color-diagnostics -Xcc -fcolor-diagnostics -Xcc -DTARGET_IPHONE=1 -Xcc -O0 -Xcc -Wall -Xcc -ggdb -Xcc -Wno-unused-command-line-argument -Xcc -Qunused-arguments -Xcc -Werror -Xcc -isysroot -Xcc "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk" -Xcc -target -Xcc arm64e-apple-ios12.2 -Xcc -fobjc-arc -Xcc -ISources/mytweakC/include -Xcc -DDEBUG -Xcc -O0 -Xcc -DTHEOS_INSTANCE_NAME="\"mytweak\"" -Xcc -fmodules -Xcc -fcxx-modules -Xcc -fmodule-name=mytweak  -Xcc -fmodules-prune-interval=86400 -Xcc -arch -Xcc arm64e -Xcc -stdlib=libc++ -Xcc [your iOS frameworks includes] -DTHEOS_SWIFT -DTARGET_IPHONE  -module-name mytweak -g  -swift-version 5 -sdk "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk"  -resource-dir /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/../lib/swift -ISources/mytweakC/include -DDEBUG -Onone -incremental -target arm64e-apple-ios12.2 -output-file-map .out/filemap.json -emit-objc-header-path .out/arm64e/mytweak-Swift.h -emit-dependencies -emit-module-path .out/arm64e/mytweak.swiftmodule Sources/mytweak/mytweak.x.swift .out/mytweak.xc.swift</span></pre>
 
## Stage three part one
Now that we compiled the Swift section of our tweak, we need to compile the obj-c part of our tweak that allows our tweak to be loaded and ran by Substrate/Libhooker. You can do that by running
<pre>
~/mytweak $ <span class="inp">clang -x objective-c -c [your iOS includes] -iquote $PWD -I$PWD/.out/arm64 -MT $PWD/.out/arm64/Tweak.m -MMD -MP -MF "$PWD/.out/arm64/Tweak.m.Td" -fcolor-diagnostics -DTARGET_IPHONE=1 -O0 -Wall -ggdb -Wno-unused-command-line-argument -Qunused-arguments -Werror  -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk" -target arm64-apple-ios12.2   -fobjc-arc -ISources/orionwithouttheosC/include -DDEBUG -O0  -DTHEOS_INSTANCE_NAME="\"mytweak\"" -arch arm64 [your iOS frameworks] Sources/mytweakC/Tweak.m -o .out/arm64/Tweak.m.o</span></pre>
 
For example, if I had Dragon installed, I would run:
<pre>
~/mytweak $ <span class="inp">clang -x objective-c -c -I$HOME/.dragon/include -I$HOME/.dragon/vendor/include -I$HOME/.dragon/include/_fallback -iquote $PWD -I$PWD/.out/arm64 -MT $PWD/.out/arm64/Tweak.m -MMD -MP -MF "$PWD/.out/arm64/Tweak.m.Td" -fcolor-diagnostics -DTARGET_IPHONE=1 -O0 -Wall -ggdb -Wno-unused-command-line-argument -Qunused-arguments -Werror  -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk" -target arm64-apple-ios12.2   -fobjc-arc -ISources/mytweakC/include -DDEBUG -O0  -DTHEOS_INSTANCE_NAME="\"mytweak\"" -arch arm64 -F$HOME/.dragon/lib -F$HOME/.dragon/vendor/lib Sources/mytweakC/Tweak.m -o .out/arm64/Tweak.m.o</span> </pre>
 
## Stage three part two
In the previous stage we compiled ARM64 now we need to compile ARM64e. You can do that by running
<pre>
~/mytweak $ <span class="inp">clang -x objective-c -c [your iOS includes] -iquote $PWD -I$PWD/.out/arm64e -MT $PWD/.out/arm64e/Tweak.m -MMD -MP -MF "$PWD/.out/arm64e/Tweak.m.Td" -fcolor-diagnostics -DTARGET_IPHONE=1 -O0 -Wall -ggdb -Wno-unused-command-line-argument -Qunused-arguments -Werror  -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk" -target arm64e-apple-ios12.2   -fobjc-arc -ISources/orionwithouttheosC/include -DDEBUG -O0  -DTHEOS_INSTANCE_NAME="\"mytweak\"" -arch arm64e [your iOS frameworks] Sources/mytweakC/Tweak.m -o .out/arm64e/Tweak.m.o</span></pre>
 
## Stage four part one
Now we need to create the dylib for our tweak. You can do this by running:
<pre>
~/mytweak $ <span class="inp">clang -fcolor-diagnostics [your iOS libraries] [your iOS frameworks] -ggdb -lobjc -framework Foundation -framework CoreFoundation -L/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/../lib/swift/iphoneos -L/usr/lib/swift -rpath /usr/lib/swift -rpath /usr/lib/libswift/stable -framework CydiaSubstrate -dynamiclib -install_name "/Library/MobileSubstrate/DynamicLibraries/mytweak.dylib"  -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk" -target arm64-apple-ios12.2  -multiply_defined suppress -stdlib=libc++ -lc++  -arch arm64  -O0 -o ".out/arm64/mytweak.dylib" .out/arm64/mytweak.x.swift.o .out/arm64/Tweak.m.o .out/arm64/mytweak.xc.swift.o</span></pre>
</pre>
 
For example, if I had Dragon installed, I would run:
<pre>
~/mytweak $ <span class="inp">clang -fcolor-diagnostics -L$HOME/.dragon/lib -F$HOME/.dragon/lib -L$HOME/.dragon/vendor/lib -F$HOME/.dragon/vendor/lib -ggdb -lobjc -framework Foundation -framework CoreFoundation -L/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/../lib/swift/iphoneos -L/usr/lib/swift -rpath /usr/lib/swift -rpath /usr/lib/libswift/stable -framework CydiaSubstrate -dynamiclib -install_name "/Library/MobileSubstrate/DynamicLibraries/mytweak.dylib"  -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk" -target arm64-apple-ios12.2  -multiply_defined suppress -stdlib=libc++ -lc++  -arch arm64  -O0 -o ".out/arm64/mytweak.dylib" .out/arm64/mytweak.x.swift.o .out/arm64/Tweak.m.o .out/arm64/mytweak.xc.swift.o</span></pre>
 
## Stage four part two
In the previous stage we compiled ARM64 now we need to compile ARM64e. You can do that by running
<pre>
~/mytweak $ <span class="inp">clang -fcolor-diagnostics -L/Users/eu/.dragon/lib -F/Users/eu/.dragon/lib -L/Users/eu/.dragon/vendor/lib -F/Users/eu/.dragon/vendor/lib -ggdb -lobjc -framework Foundation -framework CoreFoundation -L/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/../lib/swift/iphoneos -L/usr/lib/swift -rpath /usr/lib/swift -rpath /usr/lib/libswift/stable -framework CydiaSubstrate -dynamiclib -install_name "/Library/MobileSubstrate/DynamicLibraries/mytweak.dylib"  -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.5.sdk" -target arm64e-apple-ios12.2  -multiply_defined suppress -stdlib=libc++ -lc++  -arch arm64e  -O0 -o ".out/arm64e/mytweak.dylib" .out/arm64e/mytweak.x.swift.o .out/arm64e/Tweak.m.o .out/arm64e/mytweak.xc.swift.o</span></pre>
 
## Stage five
For the previous steps, we've been compiling for both ARM64 and ARM64e, creating multiple binaries, now it's time to merge them! You can do this by running:
 
<pre>
~/mytweak $ <span class="inp">lipo -arch arm64 .out/arm64/mytweak.dylib -arch arm64e .out/arm64e/mytweak.dylib -create -output .out/mytweak.dylib</span></pre>
 
## Stage six
Now we need to sign our dylib. You can do this by running:
<pre>
~/mytweak/.out $ <span class="inp">codesign -s - .out/mytweak.dylib</span></pre>
 
You now have a working dylib of a tweak written in Swift!
 
## Stage six
Now that we have the dylib, we need to create the deb. So in the .out folder run these commands
<pre>
~/mytweak/.out $ <span class="inp">mkdir deb && mkdir deb/DEBIAN && cp ../control deb/DEBIAN/ && mkdir -p Library/MobileSubstrate/DynamicLibraries && cp mytweak.dylib deb/Library/MobileSubstrate/DynamicLibraries/ && cp ../mytweak.plist deb/Library/MobileSubstrate/DynamicLibraries/ && dpkg -b deb</span></pre>
 
Now you have a deb and you can send it to your iDevice and install it and open VLC. You should see that all (or most) text labels have become uppercase with 👏 emojis instead of spaces.


