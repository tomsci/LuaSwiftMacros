// Copyright (c) 2025 Tom Sutcliffe
// See LICENSE file for license information.

import Lua

@attached(member, names: named(metatable))
@attached(extension, conformances: PushableWithMetatable)
public macro Pushable() = #externalMacro(module: "LuaMacrosImpl", type: "PushableMacro")


@attached(member, names: named(metatable))
public macro PushableSubclass<Parent>() = #externalMacro(module: "LuaMacrosImpl", type: "PushableMacro")

@attached(peer, names: arbitrary)
public macro Lua(_ visible: Bool = true, name: String? = nil)
    = #externalMacro(module: "LuaMacrosImpl", type: "LuaAttributeMacro")
