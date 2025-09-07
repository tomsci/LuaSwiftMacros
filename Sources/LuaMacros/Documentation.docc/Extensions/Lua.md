# ``LuaMacros/Lua(_:name:)``

A macro that can hide or rename a symbol from being bridged in a metatable.

## Overview

Specify `@Lua(false)` to prevent a property or function from being included in the metatable created by
[`@Pushable`](doc:Pushable()).

```swift
@Pushable
struct Foo {
    // This will mean hello() will not be bridged even though it
    // otherwise would be due to being public.
    @Lua(false)
    public func hello() -> String { return "world!" }
}
```

Specify `@Lua` or `@Lua(true)` to add a property or function to the metatable when it otherwise wouldn't be (for
example because it is `private`):

```swift
@Pushable
struct Foo {
    // This will mean hello() will be bridged even though it is private.
    @Lua
    private func hello() -> String { return "world!" }
}
```

Specify `@Lua(name: "newname")` to cause `@Pushable` to use `newname` as the Lua-side name for the property or
function:

```swift
@Pushable
class Foo {
    // Means the function will be callable from Lua as obj:helloWorld().
    @Lua(name: "helloWorld")
    public func hello_world() {
        print("Hello!")
    }
}
```

> Note: Do not use the `@Lua` macro outside of a struct/class decorated with `@Pushable` (or `@PushableSubclass`). It will have no effect, and in future versions may cause a compile error.
