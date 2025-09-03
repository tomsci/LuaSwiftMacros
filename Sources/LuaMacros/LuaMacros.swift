// Copyright (c) 2025 Tom Sutcliffe
// See LICENSE file for license information.

import Lua

/// A macro that declares a struct or class to conform to
/// [`PushableWithMetatable`](https://tomsci.github.io/LuaSwift/documentation/lua/pushablewithmetatable), and generates
/// a metatable for it.
///
/// The generated metatable will by default include all public properties and member functions defined on the type.
/// Use [`@Lua`](doc:Lua(_:name:)) to control individual symbols' visibility.
///
/// For example:
///
/// ```swift
/// import Lua
/// import LuaMacros
///
/// @Pushable
/// class Foo {
///     public var bar = "baz"
///     public func hello() -> String {
///         return "world"
///     }
/// }
/// 
/// /* The @Pushable macro above generates a declaration something like this:
/// class Foo {
///     // ...
/// 
///     class var metatable: Metatable<Foo> { return Metatable(fields: [
///         "bar": .property(\.bar),
///         "hello": .memberfn { $0.hello() }
///     ])}
/// }
/// 
/// extension Foo: PushableWithMetatable {}
/// */
/// ```
@attached(member, names: named(metatable))
@attached(extension, conformances: PushableWithMetatable)
public macro Pushable() = #externalMacro(module: "LuaMacrosImpl", type: "PushableMacro")


/// A macro that generates a metatable for a class whose parent conforms to `PushableWithMetatable`.
///
/// This is similar to [`@Pushable`](doc:Pushable()) but specifically for subclasses whose parent already uses
/// `@Pushable` (or otherwise conform to `PushableWithMetatable`). The `Parent` class type parameter should be the type
/// of the superclass with the metatable. For example:
///
/// ```swift
/// @Pushable
/// class BaseClass {
///     public func test() -> String {
///         return "Base"
///     }
/// }
/// 
/// @PushableSubclass<BaseClass>
/// class DerivedClass: BaseClass {
///     override func test() -> String {
///         return "Derived"
///     }
/// 
///     public func derivedfn() {}
/// }
/// ```
///
/// The macro assumes that `Parent` has a `metatable` that was added by `@Pushable` or `@PushableSubclass`. Unlike
/// `@Pushable`, it does not add an extension with conformance to `PushableWithMetatable` (because the superclass should
/// already have done that).
///
/// Note that it is not _required_ to use this macro on subclasses of `@Pushable` types -- if the subclass does not add
/// any new methods or properties that need to exposed to Lua, then nothing needs to be done and the parent's metatable
/// will be used automatically. `@PushableSubclass` is only necessary when the subclass has additional functions or
/// properties that need to be callable from Lua.
@attached(member, names: named(metatable))
public macro PushableSubclass<Parent>() = #externalMacro(module: "LuaMacrosImpl", type: "PushableMacro")

/// A macro that can hide or rename a symbol from being bridged in a metatable.
///
/// Specify `@Lua(false)` to prevent a property or function from being included in the metatable created by
/// `@Pushable`.
///
/// Specify `@Lua` or `@Lua(true)` to add a property or function to the metatable when it otherwise wouldn't be (for
/// example because it is `private`).
///
/// Specify `@Lua(name: "newname")` to cause `@Pushable` to use `newname` as the Lua-side name for the property or
/// function. For example:
///
/// ```swift
/// @Pushable
/// class Foo {
///     @Lua(name: "helloWorld")
///     public func hello_world() {
///         print("Hello!")
///     }
/// }
/// ```
///
/// Outside of a struct/class decorated with [`@Pushable`](doc:Pushable()) (or `@PushableSubclass`), the `@Lua` macro
/// has no effect.
@attached(peer, names: arbitrary)
public macro Lua(_ visible: Bool = true, name: String? = nil)
    = #externalMacro(module: "LuaMacrosImpl", type: "LuaAttributeMacro")
