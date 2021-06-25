# ``Orion``

A DSL for elegant tweak development in Swift.

## Overview

Orion is a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) designed to make it entirely effortless to interact with with Objective-C's dynamic aspects in Swift. The project's primary goal is to enable easy, fun, and versatile jailbreak tweak development in Swift. In some ways, it is to Swift what [Logos](https://github.com/theos/logos) is to Objective-C, but it's simultaneously a lot more than that.

It is possible to use Orion as a regular framework (invoking the preprocessor in a build script), or in a [Theos](https://github.com/theos/theos) tweak (recommended).

Orion _is not_ a framework for hooking Swift code. As of now, Orion only supports hooking Objective-C and C code, however this may change in the future.

## Topics

### Class Hooking

- ``ClassHook``
- ``ClassHookProtocol``
- ``Property``
- ``SubclassMode``
- ``DeinitPolicy``

### Function Hooking

- ``FunctionHook``
- ``FunctionHookProtocol``
- ``Function``

### All Hooks

- ``AnyHook``
- ``HookGroup``
- ``DefaultGroup``

### Tweaks

- ``Tweak``
- ``TweakWithBackend``
- ``DefaultTweak``

### Utilities

- ``Ivars``
- ``Dynamic``

### Backends

- ``Backends``
- ``Backend``
- ``DefaultBackend``
- ``HookDescriptor``

### Error Handling

- ``OrionHookError``
- ``OrionErrorHandler``
- ``updateOrionErrorHandler(_:)``
- ``orionError(_:file:line:)``

### Internals

- ``orion_init()``
