# ``LuaMacros/PushableSubclass()``

A macro that generates a metatable for a class whose parent conforms to `PushableWithMetatable`.

This is similar to [`@Pushable`](doc:Pushable()) but specifically for subclasses whose parent already uses
`@Pushable` (or otherwise conform to `PushableWithMetatable`). The `Parent` class type parameter should be the type
of the superclass with the metatable. For example:

```swift
@Pushable
class BaseClass {
    public func test() -> String {
        return "Base"
    }
}

@PushableSubclass<BaseClass>
class DerivedClass: BaseClass {
    override func test() -> String {
        return "Derived"
    }

    public func derivedfn() {}
}

/* Generates a declaration something like this:

class DerivedClass {
    // ...

    class var metatable: Metatable<BaseClass> {
        return BaseClass.metatable.subclass(type: DerivedClass.self, fields: [
            "derivedfn": .memberfn { $0.derivedfn() }
        ])
    }
}
*/
```

The macro assumes that `Parent` has a `metatable` that was added by `@Pushable` or `@PushableSubclass`. Unlike
`@Pushable`, it does not add an extension with conformance to `PushableWithMetatable` (because the superclass should
already have done that).

Note that it is not _required_ to use this macro on subclasses of `@Pushable` types -- if the subclass does not add
any new methods or properties that need to exposed to Lua, then nothing needs to be done and the parent's metatable
will be used automatically. `@PushableSubclass` is only necessary when the subclass has additional functions or
properties that need to be callable from Lua.
