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
    let visible: Bool
    let name: String?
}

public struct PushableMacro {
    private static let messageID = MessageID(domain: "LuaSwiftMacros", id: "PushableMacro")

    static func diagnostic(_ message: String, severity: DiagnosticSeverity = .error, at node: some SyntaxProtocol, context: some MacroExpansionContext) {
        let msg = LuaDiagnosticMsg(message: message, severity: severity, diagnosticID: Self.messageID)
        context.diagnose(Diagnostic(node: Syntax(node), message: msg))
    }

    static func getLuaAttribute(_ attributeList: AttributeListSyntax, context: some MacroExpansionContext) -> LuaAttribute? {
        guard let attrib = attributeList.attributeNamed("Lua")
        else {
            return nil
        }
        if attrib.arguments == nil {
            return LuaAttribute(visible: true, name: nil)
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
            return LuaAttribute(visible: true, name: nil)
        }

        if args.count != 1 {
            return badsyntax()
        }
        let param = args.first!
        if param.label == nil && param.expression.as(BooleanLiteralExprSyntax.self)?.literal.text == "false" {
            return LuaAttribute(visible: false, name: nil)
        }
        if param.label?.text == "name",
           let name = param.expression.as(StringLiteralExprSyntax.self)?.singleStringLiteral {
            return LuaAttribute(visible: true, name: name)
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
        func addField(_ k: String, _ v: String) {
            fields[k] = v
            fieldOrder.append(k)
        }

        var metaFields: [String: String] = [:]
        func addMetafield(_ k: String, _ v: String) {
            precondition(metaFields[k] == nil)
            metaFields[k] = v
        }

        var parentType: String? = nil
        let genericParams = node.attributeName.as(IdentifierTypeSyntax.self)?.genericArgumentClause?.arguments
        if let genericParams {
            if genericParams.count != 1 {
                diagnostic("Expected @PushableSubclass<ParentType>", at: node)
                return []
            }
            parentType = genericParams.first!.argument.as(IdentifierTypeSyntax.self)?.name.text
        }

        // // Gather any overrides to fields or metafields
        // if case .argumentList(let params) = node.arguments {
        //     for param in params {
        //         if param.label == "parent" {
        //             parentExpr = param.expression
        //         }
        //     }
        // }

        let structDecl = decl.as(StructDeclSyntax.self)
        let classDecl = decl.as(ClassDeclSyntax.self)
        let varType = StringLiteralType(classDecl != nil ? "class" : "static")

        guard let typeName = structDecl?.name.text ?? classDecl?.name.text else {
            diagnostic("@Pushable must be attached to a struct or class", at: decl)
            return []
        }

        if parentType != nil && classDecl == nil {
            diagnostic("@PushableSubclass<ParentType> can only be applied to a class declaration", at: node)
            return []
        }

        for member in decl.memberBlock.members {
            if let variable = member.decl.as(VariableDeclSyntax.self) {
                let luaAttribute = getLuaAttribute(variable.attributes, context: context)
                if let luaAttribute {
                    if !luaAttribute.visible {
                        continue
                    }
                    if variable.bindings.count > 1 {
                        diagnostic("Cannot apply a variable rename using @Lua(name: ...) to a declaration with multiple variables", at: variable.bindings)
                        continue
                    }
                }
                let isStatic = variable.modifiers.isStatic
                for binding in variable.bindings {
                    guard let varName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.unescapedIdentifierName else {
                        continue
                    }

                    if isStatic && varName.hasPrefix("metafield_"),
                       let accessor = binding.accessorBlock {
                        if luaAttribute != nil {
                            diagnostic("Cannot @Lua to a metafield", at: variable.attributes)
                            continue
                        }
                        addMetafield(String(varName.suffix(varName.count - 10)), "\(accessor.accessors.trimmedDescription)")
                        continue
                    }

                    let fieldName = luaAttribute?.name ?? varName
                    guard variable.modifiers.isPublic || luaAttribute?.visible == true, !fieldName.isEmpty, fields[fieldName] == nil else {
                        continue
                    }
                    if isStatic {
                        if variable.bindingSpecifier.text == "let" {
                            addField(fieldName, ".constant(\(typeName).\(varName))")
                        } else {
                            addField(fieldName, ".staticvar { return \(typeName).\(varName) }")
                        }
                    } else {
                        addField(fieldName, ".property(\\.\(varName))")
                    }
                }
            } else if let fn = member.decl.as(FunctionDeclSyntax.self) {
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

                // Technically genericParamters in the return type would be ok, so should really iterate all the arg types.
                if (fn.genericParameterClause != nil) {
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
                    addField(fieldName, ".staticfn { \(typeName).\(fnName)(\(args.joined(separator: ","))) }")
                } else {
                    addField(fieldName, ".memberfn { $0.\(fnName)(\(args.joined(separator: ","))) }")
                }
            }
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
            return [
                "\(raw: varType) var metatable: Metatable<\(raw: typeName)> { .init(\(raw: initArgs.joined(separator: ",\n")))}"
            ]
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
