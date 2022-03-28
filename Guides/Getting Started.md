# Getting Started

## Preface

If you are using Orion for tweak development, it is recommended that you use it with Theos. This guide assumes that you have Theos installed; if you haven't done that yet, please follow the [installation instructions](https://theos.dev/docs/installation) for Theos and then return to this guide.

If you wish to use Orion without Theos, please refer to the "[Using Orion Without Theos](using-orion-without-theos.html)" guide.

This guide will show you how to make a simple Orion tweak which… spices up text labels a little. We will target the VLC Media Player iOS app since it is [open source](https://github.com/videolan/vlc-ios) and supports a large range of iOS versions, however most other apps should work too.

To follow along, you will require the following things:

- [Theos](https://theos.dev/docs/installation) on a machine running macOS, Windows 10 with WSL, or Linux. If you're in a Linux environment, you must install a [host Swift toolchain](https://www.swift.org/download/) in addition to a Swift-compatible iOS toolchain.
- A jailbroken iOS device.
- The target app (in this tutorial, VLC for iOS) installed on your iOS device.

Note that this guide will use the format <pre>&lt;current directory&gt; $ <span class="inp">&lt;command&gt;</span></pre> for all shell commands. User input will be in <code><span class="inp">red</span></code>. Some text may be truncated using <code><span class="trunc">[...]</span></code>.

## Setup

1. Add the Chariz repo (https://repo.chariz.com/) to your jailbroken device's package manager, and install the **Orion Runtime** package (pick iOS 12-13 or iOS 14 depending on your version).
2. Inside your Theos installation directory (`$THEOS`), switch to the `orion` branch by running `git fetch && git checkout orion && git submodule update --init`.

## Initializing an Orion Tweak

Theos comes with a `tweak_swift` template which uses Orion.

To get started, run the New Instance Creator `nic.pl`.  Enter the template number corresponding to `iphone/tweak_swift`. Pick a name and [bundle identifier](https://cocoacasts.com/what-are-app-ids-and-bundle-identifiers/) for your tweak. Provide VLC's bundle ID: `org.videolan.vlc-ios`, as well as the full name of the VLC app _in single quotes_.

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
[iphone/tweak_swift] MobileSubstrate Bundle filter [com.apple.springboard]: <span class="inp">org.videolan.vlc-ios</span>
[iphone/tweak_swift] List of applications to terminate upon installation (space-separated, '-' for none) [SpringBoard]: <span class="inp">'VLC for iOS'</span> 
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
- `Package.swift`: This file is **not** used by Theos itself, but it provides SourceKit with an equivalent description of your project in order to enable code completion.
- `Sources`: This is where your source code goes. C/Objective-C files (`.m`, `.mm`, `.c`, `.cpp`) go in the folder with the `C` suffix, and Swift/Orion files (`.swift`, `.x.swift`) go into the folder without the suffix. Theos will automatically find these files while building your tweak, so you need not manually specify them in the `Makefile`.

## Editing your Tweak

Orion uses a preprocessor, and Theos passes all `.x.swift` files through this preprocessor while building. All hooks **must** therefore go into files with a `.x.swift` extension. The template creates a `Tweak.x.swift` for you, so we'll start by editing this.

Now, before you fire up your favorite text editor and start hammering out code in `Sources/MyTweak/Tweak.x.swift`, Theos has a trick up its sleeve: with some basic configuration, you can get **full code completion** while working on Orion tweaks on any OS, in most editors! Enabling this is simple:

1. Install the [sourcekit-lsp plugin](https://github.com/apple/sourcekit-lsp/tree/main/Editors) corresponding to your editor of choice. (If you're using Xcode, it has built-in SourceKit support so skip this step.)
2. Run `make spm` to generate metadata about your project, which is needed by Swift Package Manager/SourceKit.
3. Open the project folder in your chosen editor.

Just like that, you should have code completion! Now drill down to `Sources/MyTweak/` and select `Tweak.x.swift`. Delete the contents of the file and replace them with the following:

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

That's all for the code! You can now build, package, and install the tweak in one go:
<pre>
~/mytweak $ <span class="inp">make do</span>
<span class="ansi-r">></span> <b>Making all for tweak MyTweak…</b>
<span class="ansi-r">==></span> <b>Preprocessing Sources/MyTweak/Tweak.x.swift…</b>
<span class="ansi-r">==></span> <b>Preprocessing Sources/MyTweak/Tweak.x.swift…</b>
<span class="ansi-g">==></span> <b>Compiling Sources/MyTweak/Tweak.x.swift (arm64e)…</b>
<span class="ansi-g">==></span> <b>Compiling Sources/MyTweak/Tweak.x.swift (arm64)…</b>
<span class="ansi-b">==></span> <b>Generating MyTweak-Swift.h (arm64)…</b>
<span class="ansi-b">==></span> <b>Generating MyTweak-Swift.h (arm64e)…</b>
<span class="ansi-g">==></span> <b>Compiling Sources/MyTweakC/Tweak.m (arm64e)…</b>
<span class="ansi-g">==></span> <b>Compiling Sources/MyTweakC/Tweak.m (arm64)…</b>
<span class="ansi-y">==></span> <b>Linking tweak MyTweak (arm64)…</b>
<span class="ansi-y">==></span> <b>Linking tweak MyTweak (arm64e)…</b>
<span class="ansi-b">==></span> <b>Generating debug symbols for MyTweak…</b>
<span class="ansi-b">==></span> <b>Generating debug symbols for MyTweak…</b>
<span class="ansi-b">==></span> <b>Merging tweak MyTweak…</b>
<span class="ansi-b">==></span> <b>Signing MyTweak…</b>
<span class="ansi-r">></span> <b>Making stage for tweak MyTweak…</b>
dm.pl: building package `com.kabiroberai.mytweak:iphoneos-arm' in `./packages/com.kabiroberai.mytweak_0.0.1-1+debug_iphoneos-arm.deb'
<span class="ansi-lb">==></span> <b>Installing…</b>
(Reading database ... 3540 files and directories currently installed.)
Preparing to unpack /tmp/_theos_install.deb ...
Unpacking com.kabiroberai.mytweak (0.0.1-1+debug) ...
Setting up com.kabiroberai.mytweak (0.0.1-1+debug) ...
<span class="ansi-lb">==></span> <b>Unloading 'VLC for iOS'…</b>
</pre>

Finally, open up the VLC app on your device. You should see that all (or most) text labels have become uppercase with 👏 emojis instead of spaces.

<img src="https://orion.theos.dev/assets/vlc-tweak.png" alt="Tweaked VLC for iOS app" style="width: 100%">

## Bonus Challenge

Can you change the text to sPonGEboB cAsE? Try making the characters alternate between upper- and lowercase, or randomize whether each character is upper- or lowercase. Optionally, force certain letters to be either lowercase or uppercase; for example, try making it so the letter "L" is always uppercase and the letter "i" is always lowercase to avoid ambiguity.

<details>
<summary style="cursor: pointer">Solution</summary>

<!-- pretty much just put the code in triple backticks and copied the HTML output -->

Here's one way to achieve this:

<pre class="highlight swift"><code><span class="kd">import</span> <span class="kt">Orion</span>
<span class="kd">import</span> <span class="kt">UIKit</span>

<span class="kd">class</span> <span class="kt">LabelHook</span><span class="p">:</span> <span class="kt">ClassHook</span><span class="o">&lt;</span><span class="kt">UILabel</span><span class="o">&gt;</span> <span class="p">{</span>
    <span class="c1">// a dictionary representing characters that should always</span>
    <span class="c1">// map to a specific corresponding value</span>
    <span class="kd">private</span> <span class="kd">static</span> <span class="k">let</span> <span class="nv">mappings</span><span class="p">:</span> <span class="p">[</span><span class="kt">Character</span><span class="p">:</span> <span class="kt">Character</span><span class="p">]</span> <span class="o">=</span> <span class="p">[</span>
        <span class="s">"i"</span><span class="p">:</span> <span class="s">"i"</span><span class="p">,</span> <span class="s">"I"</span><span class="p">:</span> <span class="s">"i"</span><span class="p">,</span>
        <span class="s">"l"</span><span class="p">:</span> <span class="s">"L"</span><span class="p">,</span> <span class="s">"L"</span><span class="p">:</span> <span class="s">"L"</span><span class="p">,</span>
        <span class="s">" "</span><span class="p">:</span> <span class="s">"👏"</span>
    <span class="p">]</span>

    <span class="kd">func</span> <span class="nf">setText</span><span class="p">(</span><span class="n">_</span> <span class="nv">text</span><span class="p">:</span> <span class="kt">String</span><span class="p">)</span> <span class="p">{</span>
        <span class="k">var</span> <span class="nv">modifiedText</span> <span class="o">=</span> <span class="s">""</span>
        <span class="k">for</span> <span class="n">char</span> <span class="k">in</span> <span class="n">text</span> <span class="p">{</span>
            <span class="k">if</span> <span class="k">let</span> <span class="nv">mapping</span> <span class="o">=</span> <span class="kt">LabelHook</span><span class="o">.</span><span class="n">mappings</span><span class="p">[</span><span class="n">char</span><span class="p">]</span> <span class="p">{</span>
                <span class="n">modifiedText</span><span class="o">.</span><span class="nf">append</span><span class="p">(</span><span class="n">mapping</span><span class="p">)</span>
            <span class="p">}</span> <span class="k">else</span> <span class="k">if</span> <span class="kt">Bool</span><span class="o">.</span><span class="nf">random</span><span class="p">()</span> <span class="p">{</span>
                <span class="n">modifiedText</span> <span class="o">+=</span> <span class="n">char</span><span class="o">.</span><span class="nf">lowercased</span><span class="p">()</span>
            <span class="p">}</span> <span class="k">else</span> <span class="p">{</span>
                <span class="n">modifiedText</span> <span class="o">+=</span> <span class="n">char</span><span class="o">.</span><span class="nf">uppercased</span><span class="p">()</span>
            <span class="p">}</span>
        <span class="p">}</span>
        <span class="n">orig</span><span class="o">.</span><span class="nf">setText</span><span class="p">(</span><span class="n">modifiedText</span><span class="p">)</span>
    <span class="p">}</span>
<span class="p">}</span>
</code></pre>
<em>Bonus-bonus-challenge: add support for languages besides English :)</em>
</details>
