// Copyright (c) 2025 Tom Sutcliffe
// See LICENSE file for license information.

import Lua

@attached(member, names: named(metatable), named(metaobject))
@attached(extension, conformances: PushableWithMetatable)
public macro Pushable() = #externalMacro(module: "LuaMacrosImpl", type: "PushableMacro")

@attached(member, names: named(metatable), named(metaobject))
@attached(extension, conformances: PushableWithMetatable)
public macro PushableEnum(typeName: String?) = #externalMacro(module: "LuaMacrosImpl", type: "PushableMacro")

@attached(member, names: named(metatable))
public macro PushableSubclass<Parent>() = #externalMacro(module: "LuaMacrosImpl", type: "PushableMacro")

@attached(peer, names: arbitrary)
public macro Lua(_ visible: Bool = true, name: String... = [])
    = #externalMacro(module: "LuaMacrosImpl", type: "LuaAttributeMacro")
