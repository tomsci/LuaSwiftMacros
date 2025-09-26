# ``LuaMacros/PushableEnum(typeName:)``

A macro for making enums `Pushable`.

## Overview

This macro behaves identically to [`@Pushable`](doc:Pushable()), except that it is specifically only for enums, and it allows the name of the generated `type` field to be customised (or removed entirely) in the generated metatable.

## Changing the type field name

To have an enum's type metatable field be called `_type` instead, do:

```swift
@PushableEnum(typeName: "_type")
enum Example {
    case foo
    case bar
}

// In Lua you could write: if val._type == "foo" then ... end
```

The `typeName` can be `nil` to remove the field entirely. This can make the enum hard to use from Lua however. One scenario where removing the type field can make sense is if every case of the enum has an associated value (and that value isn't optional). The example below also sets the associated property name to be the case name, rather than the default (which would be `foo_value` and `bar_value` in this example).

```swift
@PushableEnum(typeName: nil)
enum Example {
    @Lua(name: "foo") case foo(Int)
    @Lua(name: "bar") case bar(String)
}

// In Lua you could now test for `val.foo` or `val.bar` being non-nil
// to distinguish the enum cases.
```

Another scenario where the type field may be unnecessary is if the enum implements Equatable, has no associated values, and all the cases are made available for comparison Lua-side, for example by using [`push(enum:)`](https://tomsci.github.io/LuaSwift/documentation/lua/swift/unsafemutablepointer/push(enum:toindex:)) (or, as in the example below, the `.enum` helper which ultimately calls `push(enum:)`).

```swift
@PushableEnum(typeName: nil)
enum Example: Equatable, CaseIterable {
    case foo
    case bar
}

L.setglobal(name: "Example", value: .enum(Example.self))
// Can now test the value in Lua by comparing it against Example.foo 
```