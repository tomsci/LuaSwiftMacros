# ``LuaMacros/Pushable()``

A macro that adds conformance to `PushableWithMetatable`.

## Overview

A macro that declares a struct or class to conform to [`PushableWithMetatable`](https://tomsci.github.io/LuaSwift/documentation/lua/pushablewithmetatable), and generates a metatable for it.

The generated metatable will by default include all public properties and member functions defined on the type. Use [`@Lua`](doc:Lua(_:name:)) to control individual symbols' visibility.

For example:

```swift
import Lua
import LuaMacros

@Pushable
class Foo {
    public var bar = "baz"
    public func hello() -> String {
        return "world"
    }
}

/* The @Pushable macro above generates a declaration something like this:
class Foo {
    // ...

    class var metatable: Metatable<Foo> { return Metatable(fields: [
        "bar": .property(\.bar),
        "hello": .memberfn { $0.hello() }
    ])}
}

extension Foo: PushableWithMetatable {}
*/
```

## Customising the metatable

Metafields may be added to the generated metatable, if required. This is done by declaring private variables named `metafield_<name>`, in the declaration the `@Pushable` is attached to. For example, to add a `close` metamethod, declare a `metafield_close` property of type `Metatable<T>.CloseType`:

```swift
@Pushable
class Foo {
    public func close() { print("Closed!") }

    private static var metafield_close: Metatable<Foo>.CloseType {
        .memberfn { $0.close() }
    }
}
```

Some protocols, specifically `Equatable`, `Comparable` and `Closable`, are automatically added to the metatable if the struct/class conforms to them (as `eq`, `lt`, `le`, and `close` metamethods). Hence the above could have been written:

```swift
@Pushable
class Foo: Closable {
    public func close() { print("Closed!") }
}
```

The macro can only check for direct conformance however, so manually specifying them (with for example `metafield_close { .synthesize }`) can be necessary in some contexts. Conversely, if the Swift type conforms to one of those protocols but you _don't_ want the Lua type to automatically synthesize a metafield from it, include a `metafield_x` member with the value `.none`:

```swift
@Pushable
struct Foo: Equatable {
    public let val: Int

    // Override the Equatable and make the Lua type _not_ have an eq metamethod
    private static var metafield_eq: Metatable<Foo>.EqType { .none }
}
```
