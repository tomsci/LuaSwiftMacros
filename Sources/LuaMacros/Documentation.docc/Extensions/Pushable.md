# ``LuaMacros/Pushable()``

A macro that adds conformance to `PushableWithMetatable`.

## Overview

A macro that declares a struct, class or enum to conform to [`PushableWithMetatable`](https://tomsci.github.io/LuaSwift/documentation/lua/pushablewithmetatable), and generates a metatable for it. In other words, it makes a type usable from Lua via the LuaSwift [bridging](https://tomsci.github.io/LuaSwift/documentation/lua/bridgingswifttolua) mechanism.


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

In the example above, instances of the class `Foo` can now be used from Lua, and the `bar` and `hello()` members can be accessed.

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

Some protocols, specifically `Equatable`, `Comparable` and `Closable`, are automatically added to the metatable if the type conforms to them (as `eq`, `lt`, `le`, and `close` metamethods). Hence the above could have been written:

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

## Enums

`enum` types are handled specially by `@Pushable`. They are made pushable using a `userdata`, as with structs and classes, and any static and member properties and functions are added to that as usual. The difference is (not surprisingly) how the cases are treated. Since there is no way to exactly replicate Swift's `if case` or `switch` constructs in Lua, establishing what the value is and what any associated values are, requires establishing some new conventions for how the value should be accessed when bridged into Lua. The conventions used by `@Pushable` are:

* The case name is available as a string property called `type`.
* Any case with a single associated value adds a property called `<casename>_value`. This property is `nil` for any instance of the enum that is not of this case. If the associated value has a name (ie the parameter clause is a named tuple) which doesn't conflict with anything else, that name is used for the property instead.
* If a case has multiple associated values multiple properties are added as above, except that they are named `<casename>_1`, `<casename>_2` etc if the associated values are unnamed.
* Associated value names can be customised using the `@Lua(name:)` macro.

For example an enum like this:

```swift
@Pushable
enum Example {
    case simple
    case onevalue(String)
    case twovals(Int, String)
}
```

Would result in a value that could be used in Lua like this:

```lua
function describeEnumVal(val)
    if val.type == "simple" then
        print("Example.simple")
    elseif val.type == "onevalue" then
        -- Could also have tested for val.onevalue_value ~= nil
        print(string.format("Example.onevalue(%s)", val.onevalue_value))
    elseif val.type == "twovals" then
        print(string.format("Example.twovals(%d, %s)", val.twovals_1, val.twovals_2))
    else
        error("Bad value")
    end
end
```

To customize the associated value property names, use [`@Lua(name: ...)`](doc:Lua(_:name:)), passing multiple names if there is more than one associated value:

```swift
@Pushable
enum Example {
    case simple
    
    @Lua(name: "oneval")
    case onevalue(String)

    @Lua(name: "twovalint", "twovalstr")
    case twovals(Int, String)
}
// The Lua value has the following properties: type, oneval, twovalint and twovalstr
```

To change the name of the `type` field (or remove it entirely), use [`@PushableEnum(typeName:)`](doc:PushableEnum(typeName:))

> Note: If your enum does not have any associated values and is (or can be made to be) `RawRepresentable`, then using [`RawPushable`](https://tomsci.github.io/LuaSwift/documentation/lua/rawpushable) and/or [`push(enum:)`](https://tomsci.github.io/LuaSwift/documentation/lua/swift/unsafemutablepointer/push(enum:toindex:)) may be a simpler alternative.
