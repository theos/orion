# Getting Started

## Preface

If you are using Orion for tweak development, it is recommended that you use it with Theos. This guide assumes that you have Theos installed; if you haven't done that yet, please follow the [installation instructions](https://github.com/theos/theos/wiki/Installation) for Theos and then return to this guide.

If you wish to use Orion without Theos, please refer to the "[Using Orion Without Theos](/using-orion-without-theos.html)" guide.

This guide will show you how to make a simple SpringBoard tweak with Orion, which changes the opacity of the dock. This means you need to have a jailbroken iOS device to code along. If you do not have a jailbroken iOS device, you can make tweaks for non-jailbroken devices as well using [Theos Jailed](https://github.com/kabiroberai/theos-jailed).

Note that this guide will use the format <pre>&lt;current directory&gt; $ <span class="inp">&lt;command&gt;</span></pre> for all shell commands. User input will be in <code><span class="inp">red</span></code>. Some text may be truncated using <code><span class="trunc">[...]</span></code>.

## Initializing an Orion Tweak

Theos comes with a `tweak_swift` template which uses Orion.

To get started, run the New Instance Creator `nic.pl`.  Enter the template number corresponding to `iphone/tweak_swift`. Pick a name and [bundle identifier](https://cocoacasts.com/what-are-app-ids-and-bundle-identifiers/) for your tweak. We're going to be creating a SpringBoard tweak, so leave the bundle filter and list of apps to terminate as is (simply hit return for both those prompts).

<pre>
~ $ <span class="inp">nic.pl</span>
NIC 2.0 - New Instance Creator
------------------------------
  [1.] iphone/activator_event
  [2.] iphone/activator_listener
  <span class="trunc">[...]</span>
  [16.] iphone/tweak
  [17.] iphone/tweak_swift
  [18.] iphone/tweak_with_simple_preferences
  [19.] iphone/xpc_service
Choose a Template (required): <span class="inp">17</span>
Project Name (required): <span class="inp">My Tweak</span>     
Package Name [com.yourcompany.mytweak]: <span class="inp">com.kabiroberai.mytweak</span>
Author/Maintainer Name [Your Name]: <span class="inp">Kabir Oberai</span>
[iphone/tweak_swift] MobileSubstrate Bundle filter [com.apple.springboard]: 
[iphone/tweak_swift] List of applications to terminate upon installation (space-separated, '-' for none) [SpringBoard]: 
Instantiating iphone/tweak_swift in mytweak/...
Done.
</pre>

NIC will create a directory with the same name as your tweak. `cd` into this directory and take a minute to look around. The file structure looks like this:

<pre>
- Makefile
- MyTweak.plist
- control
- Package.swift
- Sources
  - MyTweak
    - Tweak.x.swift
  - MyTweakC
    - <span class="trunc">[...]</span>
</pre>

The number of files might seem daunting at first, but each one has a specific purpose which you'll quickly come to learn. Here's a brief description:

- `Makefile`: This file is the keystone of any Theos project. It describes how your tweak should be built, including the list of source files as well as the flags that should be passed to the compiler.
- `MyTweak.plist`: This is the [CydiaSubstrate bundle filter](https://iphonedevwiki.net/index.php/Cydia_Substrate#Filters) for your tweak. It tells CydiaSubstrate (or an equivalent tweak loader) which processes your tweak should be loaded into.
- `control`:  The Debian [control file](https://iphonedevwiki.net/index.php/Packaging#Control_file) which describes your tweak's .deb package to package managers.
- `Package.swift`: This file is **not** used by Theos itself, but it helps provide Xcode with a description of your tweak's files and compiler flags which is similar to that provided to Theos by the Makefile. This allows you to edit your tweak using the Xcode IDE, with full code completion and whatnot. You'll want to keep this in sync with any changes you make to your Makefile.
- `Sources`: This is where your source code goes. C/Objective-C files (`.m`, `.mm`, `.c`, `.cpp`) go in the folder with the `C` suffix, and Swift/Orion files (`.swift`, `.x.swift`) go into the folder without the suffix. Theos will automatically find these files while building your tweak, so you need not manually specify them in the `Makefile`. 

For more details about the Theos side of things, see [Advanced Theos Usage](/advanced-theos-usage.html).

## Editing your Tweak

Orion uses a preprocessor, and Theos passes all `.x.swift` files through this preprocessor while building. All hooks **must** therefore go into files with a `.x.swift` extension. The template creates a `Tweak.x.swift` for you, so we'll start by editing this.

Now, while one option is to open `Sources/MyTweak/Tweak.x.swift` in your favorite text editor, Orion offers an even better option on macOS: editing your tweak in Xcode!

Opening your tweak in Xcode is simple:

<pre>
~/mytweak $ <span class="inp">make dev</span>
</pre>

This should open Xcode with your tweak as a Swift Package. Drill down to `Sources/MyTweak/` and select `Tweak.x.swift`. Delete the contents of the file and replace them with the following:

```swift
import UIKit
// 1
import Orion

// 2
class MyHook: ClassHook<UIView> {
    // 3
    static let targetName = "SBDockView"
}
```

TODO: Finish this tutorial
