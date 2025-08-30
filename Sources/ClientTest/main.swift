// Copyright (c) 2025 Tom Sutcliffe
// See LICENSE file for license information.

import Lua
import LuaMacros

@Pushable
struct Foo {
    public let bar: String
    public var `public` = "sure"

    public func wat(arg: Int) -> String? {
        return "\(arg)"
    }

    public func nope<T>(_ arg: T) -> T {
        return arg
    }
}

@Pushable
struct Doom<T> {
    public let val: T
}

@Pushable
struct ClosableStruct: Closable {
    var closed = false

    mutating func close() {
        closed = true
    }
}

@Pushable
class ClosableClass: Closable {
    var closed = false

     func close() {
        closed = true
    }
}

@Pushable // (equatable: true)
struct EqThing: Equatable {
    var value: Int
    public static func == (lhs: EqThing, rhs: EqThing) -> Bool {
        return lhs.value == rhs.value
    }
}

@Pushable
struct StaticFn {
    public static func foo() -> Bool {
        return false
    }
}

@Pushable
struct StaticConstant {
    public static let foo = "bar"
    public static var nope: Int { 42 }
}

@Pushable
struct Wat {
    func docall() -> String { return "Hello!" }

    private static var metafield_eq: Metatable<Wat>.EqType { .closure { L in L.push(false); return 1 } }
    private static var metafield_call: Metatable<Wat>.CallType { .memberfn { $0.docall() } }
}

@Pushable
struct NotEq : Equatable {
    public let val: Int

    private static var metafield_eq: Metatable<NotEq>.EqType { .none }

}

@Pushable
struct Order {
    private static var metafield_call: Metatable<Wat>.CallType { .closure { L in return 0 } }
    private static var metafield_eq: Metatable<Wat>.EqType { .closure { L in L.push(false); return 1 } }
}

@Pushable
struct CustomMember {

    @Lua(name: "fooooo")
    var foo: String

//    private static var metafield_call: Metatable<Wat>.CallType { .closure { L in return 0 } }
//    private static var metafield_eq: Metatable<Wat>.EqType { .closure { L in L.push(false); return 1 } }
}



//@PushableT(Metatable<ExtraMemberFn>(fields: ["woop": .memberfn { $0._woop() }]))
//struct ExtraMemberFn {
//    public func _woop() {}
//}


//let a = 17
//let b = 25
//let (result, code) = #stringify(a + b)
//print("The value \(result) was produced by the code \"\(code)\"")

//let L = LuaState(libraries: .all)
//L.setglobal(name: "foo", value: Foo(bar: ""))
//try L.dostring("print(string.format('%q', foo:wat(1234)))")
//L.close()
