// Copyright (c) 2025 Tom Sutcliffe
// See LICENSE file for license information.

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// Essential reading:
// https://swiftpackageindex.com/swiftlang/swift-syntax/601.0.1/documentation/swiftsyntax
// https://swift-ast-explorer.com/
// https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes#attached

let metafieldOrder = [
    "add",
    "sub",
    "mul",
    "div",
    "mod",
    "pow",
    "unm",
    "idiv",
    "band",
    "bor",
    "bxor",
    "bnot",
    "shl",
    "shr",
    "concat",
    "len",
    "eq",
    "lt",
    "le",
    "index",
    "newindex",
    "call",
    "close",
    "tostring",
    "pairs",
    "name"
]

extension DeclModifierListSyntax {
    var isPublic: Bool {
        for decl in self {
            if decl.name.text == "public" {
                return true
            }
        }
        return false
    }

    var isStatic: Bool {
        for decl in self {
            if decl.name.text == "static" {
                return true
            }
        }
        return false
    }

    var isStaticOrClass: Bool {
        for decl in self {
            if decl.name.text == "static" || decl.name.text == "class" {
                return true
            }
        }
        return false
    }
}

extension TokenSyntax {
    var unescapedIdentifierName: String? {
        var text = self.text
        if text.hasPrefix("`") && text.hasSuffix("`") {
            text = String(String(text.suffix(text.count - 1)).prefix(text.count - 2))
        }

        let firstch = text.first!
        if !firstch.isASCII || (!firstch.isLetter && firstch != "_") {
            return nil
        }

        return text
    }
}

extension AttributeListSyntax {
    func attributeNamed(_ name: String) -> AttributeSyntax? {
        for attrib in self {
            if let found = attrib.as(AttributeSyntax.self),
               found.attributeName.trimmedDescription == name {
                return found
            }
        }
        return nil
    }
}

extension StringLiteralExprSyntax {
    var singleStringLiteral: String? {
        guard self.segments.count == 1 else {
            return nil
        }
        return self.segments.first?.as(StringSegmentSyntax.self)?.content.text
    }
}

internal struct LuaDiagnosticMsg : DiagnosticMessage {
    let message: String
    let severity: DiagnosticSeverity
    let diagnosticID: MessageID
}

internal struct LuaAttribute {
    let node: AttributeSyntax
    let visible: Bool
    let names: [String]

    var name: String? { names.first }
}

public struct PushableMacro {
    private static let messageID = MessageID(domain: "LuaSwiftMacros", id: "PushableMacro")

    static func diagnostic(_ message: String, severity: DiagnosticSeverity = .error, at node: some SyntaxProtocol, context: some MacroExpansionContext) {
        let msg = LuaDiagnosticMsg(message: message, severity: severity, diagnosticID: Self.messageID)
        context.diagnose(Diagnostic(node: Syntax(node), message: msg))
    }

    static func getLuaAttribute(_ attributeList: AttributeListSyntax, context: some MacroExpansionContext, isCase: Bool = false) -> LuaAttribute? {
        guard let attrib = attributeList.attributeNamed("Lua")
        else {
            return nil
        }
        if attrib.arguments == nil {
            return LuaAttribute(node: attrib, visible: true, names: [])
        }

        guard let args = attrib.arguments?.as(LabeledExprListSyntax.self)
        else {
            return nil
        }

        func badsyntax() -> LuaAttribute? {
            diagnostic("Expected @Lua(false) or @Lua(name: \"...\")", at: attributeList, context: context)
            return nil
        }
        if args.count == 0 {
            // Same as @Lua(true)
            return LuaAttribute(node: attrib, visible: true, names: [])
        }

        let param = args.first!

        if param.label?.text == "name" {
            guard let name = param.expression.as(StringLiteralExprSyntax.self)?.singleStringLiteral else {
                return badsyntax()
            }
            var names = [name]
            if isCase {
                // More than one name is allowed (and is checked by the caller)
                for (i, arg) in args.enumerated() {
                    if i == 0 {
                        continue
                    }
                    guard arg.label == nil, let nextName = arg.expression.as(StringLiteralExprSyntax.self)?.singleStringLiteral else {
                        diagnostic("Expected @Lua(name: \"firstValName\", [\"secondValName\", ...])", at: arg, context: context)
                        return nil
                    }
                    names.append(nextName)
                }
            } else {
                if args.count != 1 {
                    return badsyntax()
                }
            }

            return LuaAttribute(node: attrib, visible: true, names: names)
        }

        if args.count == 1 && param.label == nil && param.expression.as(BooleanLiteralExprSyntax.self)?.literal.text == "false" {
            return LuaAttribute(node: attrib, visible: false, names: [])
        }

        return badsyntax()
    }
}

extension PushableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo decl: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // This fn is never called for PushableSubclass in real use, but the tests do not account for the lack of
        // @attached(extension) in LuaMacros (I assume they just introspect whatever PushableMacro conforms to) so we
        // have to have this check.
        let macroName = node.attributeName.as(IdentifierTypeSyntax.self)!.name.text
        if macroName == "PushableSubclass" {
            return []
        }

        return [try ExtensionDeclSyntax(
            """
            extension \(type): PushableWithMetatable {}
            """)]
    }
}

extension PushableMacro: MemberMacro {
    public static func expansion(
      of node: AttributeSyntax,
      providingMembersOf decl: some DeclGroupSyntax,
      conformingTo protocols: [TypeSyntax],
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        func diagnostic(_ message: String, severity: DiagnosticSeverity = .error, at node: some SyntaxProtocol) {
            Self.diagnostic(message, severity: severity, at: node, context: context)
        }

        var fields: [String: String] = [:]
        var fieldOrder: [String] = []
        func addField(_ k: String, _ v: String, node: some SyntaxProtocol) {
            guard fields[k] == nil else {
                diagnostic("@Pushable macro has resulted in duplicate field definition for \(k) - try using @Lua(name:) to rename one of them?", at: node)
                return
            }
            fields[k] = v
            fieldOrder.append(k)
        }

        var metaFields: [String: String] = [:]
        func addMetafield(_ k: String, _ v: String) {
            precondition(metaFields[k] == nil)
            metaFields[k] = v
        }

        var metaobjFields: [String: String] = [:]
        var metaobjFieldOrder: [String] = []
        func addMetaobjField(_ k: String, _ v: String, node: some SyntaxProtocol) {
            guard metaobjFields[k] == nil else {
                diagnostic("@Pushable macro has resulted in duplicate metaobj field definition for \(k) - try using @Lua(name:) to rename one of them?", at: node)
                return
            }
            metaobjFields[k] = v
            metaobjFieldOrder.append(k)
        }

        let macroIdentifier = node.attributeName.as(IdentifierTypeSyntax.self)!
        let macroName = macroIdentifier.name.text

        var parentType: String? = nil
        let genericParams = macroIdentifier.genericArgumentClause?.arguments
        if let genericParams {
            if genericParams.count != 1 {
                diagnostic("Expected @PushableSubclass<ParentType>", at: node)
                return []
            }
            parentType = genericParams.first!.argument.as(IdentifierTypeSyntax.self)?.name.text
        }

        // Check for any params
        var enumTypeField: String? = "type"
        if case .argumentList(let params) = node.arguments {
            for param in params {
                if macroName == "PushableEnum" && param.label?.text == "typeName" {
                    if param.expression.as(NilLiteralExprSyntax.self) != nil {
                        enumTypeField = nil
                    } else if let str = param.expression.as(StringLiteralExprSyntax.self)?.singleStringLiteral {
                        enumTypeField = str
                    } else {
                        diagnostic("typeName must be a single string literal", at: param.expression)
                        return []
                    }
                } else {
                    preconditionFailure("Unexpected parameter in macro")
                }
            }
        }

        let enumDecl = decl.as(EnumDeclSyntax.self)
        if enumDecl == nil {
            enumTypeField = nil
        }
        let structDecl = decl.as(StructDeclSyntax.self)
        let classDecl = decl.as(ClassDeclSyntax.self)
        let varType = StringLiteralType(classDecl != nil ? "class" : "static")

        guard let typeName = structDecl?.name.text ?? classDecl?.name.text ?? enumDecl?.name.text else {
            diagnostic("@Pushable must be attached to a struct, class or enum", at: decl)
            return []
        }

        if parentType != nil && classDecl == nil {
            diagnostic("@PushableSubclass<ParentType> can only be applied to a class declaration", at: node)
            return []
        }

        if macroName == "PushableEnum" && enumDecl == nil {
            diagnostic("@PushableEnum can only be applied to an enum", at: node)
            return []
        }

        var enumCaseNames: [String] = []
        var enumValCount: [String : Int] = [:]

        for member in decl.memberBlock.members {
            // enum case declaration
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                let luaAttribute = getLuaAttribute(caseDecl.attributes, context: context, isCase: true)
                if luaAttribute != nil && caseDecl.elements.count != 1 {
                    diagnostic("Cannot apply @Lua to a case statement with multiple elements", at: caseDecl)
                    enumTypeField = nil
                    break
                }
                for element in caseDecl.elements {
                    let name = element.name.text
                    enumCaseNames.append(name)
                    if let parameterClause = element.parameterClause {
                        if let luaAttribute, luaAttribute.names.count != parameterClause.parameters.count {
                            diagnostic("@Lua(name: ...) applied to a case statament must have the same number of names as there are associated values", at: luaAttribute.node)
                            enumTypeField = nil
                            break
                        }
                        enumValCount[name] = parameterClause.parameters.count
                        var constructorParams: [String] = []
                        for (i, param) in parameterClause.parameters.enumerated() {
                            let namedParameterName = param.firstName?.text
                            var clause: String
                            if i == 0 {
                                clause = "let value"
                            } else {
                                clause = Array(repeating: "_", count: i).joined(separator: ", ") + ", let value"
                            }
                            if i + 1 < parameterClause.parameters.count {
                                clause = clause + ", " + Array(repeating: "_", count: parameterClause.parameters.count - (i + 1)).joined(separator: ", ")
                            }
                            let fieldName: String
                            if let luaAttribute {
                                fieldName = luaAttribute.names[i]
                            } else if let namedParameterName, fields[namedParameterName] == nil {
                                fieldName = namedParameterName
                            } else if parameterClause.parameters.count == 1 || namedParameterName != nil {
                                fieldName = "\(name)_\(namedParameterName ?? "value")"
                            } else {
                                fieldName = "\(name)_\(i+1)"
                            }
                            addField(fieldName, """
                                .property(get: { obj -> Optional<\(param.type)> in
                                if case .\(name)(\(clause)) = obj { return value } else { return nil } })
                                """, node: param)
                            if let namedParameterName {
                                constructorParams.append("\(namedParameterName): $\(i)")
                            } else {
                                constructorParams.append("$\(i)")
                            }
                        }
                        addMetaobjField(name, ".staticfn { return \(typeName).\(name)(\(constructorParams.joined(separator: ", "))) }", node: element)
                    } else {
                        enumValCount[name] = 0
                        addMetaobjField(name, ".staticvar { return \(typeName).\(name) }", node: element)
                    }
                }
            }

            if let variable = member.decl.as(VariableDeclSyntax.self) {
                // variable declaration
                let luaAttribute = getLuaAttribute(variable.attributes, context: context)
                if let luaAttribute {
                    if !luaAttribute.visible {
                        continue
                    }
                    if variable.bindings.count > 1 && luaAttribute.name != nil {
                        diagnostic("Cannot apply a variable rename using @Lua(name: ...) to a declaration with multiple variables", at: variable.bindings)
                        continue
                    }
                }
                let isStatic = variable.modifiers.isStaticOrClass
                for binding in variable.bindings {
                    guard let varName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.unescapedIdentifierName else {
                        continue
                    }

                    if isStatic && varName.hasPrefix("metafield_") {
                        if luaAttribute != nil {
                            diagnostic("Cannot apply @Lua to a metafield", at: variable.attributes)
                            continue
                        }
                        addMetafield(String(varName.suffix(varName.count - 10)), "\(varName)")
                        continue
                    }

                    let fieldName = luaAttribute?.name ?? varName
                    guard variable.modifiers.isPublic || luaAttribute?.visible == true, !fieldName.isEmpty, fields[fieldName] == nil else {
                        continue
                    }
                    if isStatic {
                        if variable.bindingSpecifier.text == "let" {
                            addField(fieldName, ".constant(\(typeName).\(varName))", node: binding)
                        } else {
                            addField(fieldName, ".staticvar { return \(typeName).\(varName) }", node: binding)
                        }
                    } else {
                        addField(fieldName, ".property(\\.\(varName))", node: binding)
                    }
                }
            } else if let fn = member.decl.as(FunctionDeclSyntax.self) {
                // function declaration
                guard let fnName = fn.name.unescapedIdentifierName else {
                    continue
                }
                let luaAttribute = getLuaAttribute(fn.attributes, context: context)
                if let luaAttribute {
                    if !luaAttribute.visible {
                        continue
                    }
                }

                if (!fn.modifiers.isPublic && luaAttribute?.visible != true) {
                    continue
                }

                if (fn.genericParameterClause != nil) {
                    diagnostic("Cannot bridge functions with generic parameters, specify @Lua(false) to prevent this warning.", severity: .warning, at: fn)
                    continue
                }

                var args: [String] = []
                let isStaticFn = fn.modifiers.isStatic
                let paramStartIdx = isStaticFn ? 0 : 1
                for (i, param) in fn.signature.parameterClause.parameters.enumerated() {
                    if param.firstName.text == "_" {
                        // Anonymous param
                        args.append("$\(paramStartIdx + i)")
                    } else {
                        args.append("\(param.firstName.text): $\(paramStartIdx + i)")
                    }
                }
                let fieldName = luaAttribute?.name ?? fnName
                if isStaticFn {
                    addField(fieldName, ".staticfn { \(typeName).\(fnName)(\(args.joined(separator: ","))) }", node: fn)
                } else {
                    addField(fieldName, ".memberfn { $0.\(fnName)(\(args.joined(separator: ","))) }", node: fn)
                }
            }
        }

        if let enumTypeField {
            var cases: [String] = []
            for caseName in enumCaseNames {
                let numParams = enumValCount[caseName]!
                let params = numParams == 0 ? "" : "(" + Array(repeating: "_", count: numParams).joined(separator: ", ") + ")"
                cases.append("case .\(caseName)\(params): return \"\(caseName)\"")
            }
            addField(enumTypeField, ".property(get: { switch $0 { \(cases.joined(separator: "\n")) } })", node: enumDecl!)
        }

        if let inheritedTypes = decl.inheritanceClause?.inheritedTypes {
            // Actual type information isn't available here, so all we can do is guess that the name corresponds to the
            // type we're looking for.
            let conformsToComparable = inheritedTypes.contains(where: { inherited in
                let name = inherited.type.trimmedDescription
                return name == "Comparable" || name == "Swift.Comparable"
            })
            let conformsToEquatable = inheritedTypes.contains(where: { inherited in
                let name = inherited.type.trimmedDescription
                return name == "Equatable" || name == "Swift.Equatable"
            })

            if conformsToEquatable && metaFields["eq"] == nil {
                addMetafield("eq", ".synthesize")
            }

            if conformsToComparable && metaFields["le"] == nil && metaFields["lt"] == nil {
                addMetafield("lt", ".synthesize")
                addMetafield("le", ".synthesize")
            }
            if conformsToComparable && metaFields["eq"] == nil {
                addMetafield("eq", ".synthesize")
            }

            let conformsToClosable = inheritedTypes.contains(where: { inherited in
                let name = inherited.type.trimmedDescription
                return name == "Closable" || name == "Lua.Closable"
            })
            if conformsToClosable && metaFields["close"] == nil {
                addMetafield("close", ".synthesize")
            }
        }

        var fieldPairs: [String] = []
        for name in fieldOrder {
            fieldPairs.append("\"\(name)\": \(fields[name]!)")
        }

        let fieldsStr = fieldPairs.isEmpty ? "[:]" : "[\n" + fieldPairs.joined(separator: ",\n") + "\n]"
        var initArgs = [ "fields: \(fieldsStr)" ]
        for name in metafieldOrder {
            if let val = metaFields[name] {
                initArgs.append("\(name): \(val)")
            }
        }

        if let parentType {
            return [
                "class override var metatable: Metatable<\(raw: parentType)> { \(raw: parentType).metatable.subclass(type: \(raw: typeName).self, \(raw: initArgs.joined(separator: ",\n")))}"
            ]
        } else {
            var result: [DeclSyntax] = [
                "\(raw: varType) var metatable: Metatable<\(raw: typeName)> { .init(\(raw: initArgs.joined(separator: ",\n")))}"
            ]
            if !metaobjFields.isEmpty {
                var pairs: [String] = []
                for name in metaobjFieldOrder {
                    pairs.append("\"\(name)\": \(metaobjFields[name]!)")
                }
                result.append("static var metaobject: Metaobject<\(raw: typeName)> { .init(metatable: \(raw: typeName).metatable, fields: [\n\(raw: pairs.joined(separator: ",\n"))]) }")
            }
            return result
        }
    }
}

public struct LuaAttributeMacro {
    private static let messageID = MessageID(domain: "LuaSwiftMacros", id: "LuaAttributeMacro")

    static func diagnostic(_ message: String, severity: DiagnosticSeverity = .error, at node: some SyntaxProtocol, context: some MacroExpansionContext) {
        let msg = LuaDiagnosticMsg(message: message, severity: severity, diagnosticID: Self.messageID)
        context.diagnose(Diagnostic(node: Syntax(node), message: msg))
    }
}

extension LuaAttributeMacro : PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {

        // This doesn't need to actually do anything, it just needs to exist for PushableMacro to pick up as an attribute
        return []
    }
}

@main
struct LuaSwiftMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PushableMacro.self,
        LuaAttributeMacro.self,
    ]
}
