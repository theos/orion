<h1 align="center">Orion</h1>
<p align="center"><strong>A DSL for elegant tweak development in Swift.</strong></p>
<p align="center">
<a href="https://theos.dev">Theos</a> –
<a href="https://orion.theos.dev/getting-started.html">Documentation</a> –
<a href="https://github.com/theos/orion/releases">Changelogs</a> –
<a href="https://github.com/theos/theos/wiki/Help">Get Help</a> –
<a href="https://twitter.com/theosdev">@theosdev</a> –
<a href="https://iphonedevwiki.net/index.php/How_to_use_IRC">IRC</a>
</p>

## About

Orion is a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) designed to make it entirely effortless to interact with with Objective-C's dynamic aspects in Swift. The project's primary goal is to enable easy, fun, and versatile jailbreak tweak development in Swift. In some ways, it is to Swift what [Logos](https://github.com/theos/logos) is to Objective-C, but it's simultaneously a lot more than that.

It is possible to use Orion as a regular framework (invoking the preprocessor in a build script), or in a [Theos](https://github.com/theos/theos) tweak (recommended).

Orion _is not_ a framework for hooking Swift code. As of now, Orion only supports hooking Objective-C and C code, however this may change in the future.

For more information, refer to the [documentation](https://orion.theos.dev/getting-started.html).

## Example

The following is a simple tweak which changes the text of all labels to say "hello":

```swift
class MyHook: ClassHook<UILabel> {
    func setText(_ text: String) {
        orig.setText("hello")
    }
}
```

## License

See [LICENSE.md](https://github.com/theos/orion/blob/master/LICENSE.md) for licensing information.
