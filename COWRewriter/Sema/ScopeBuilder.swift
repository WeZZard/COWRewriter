//
//  ScopeBuilder.swift
//  COWRewriter
//
//  Created by WeZZard on 6/3/22.
//

import OSLog
import SwiftSyntax


class ScopeBuilder {
  
  let file: String
  
  let tree: SourceFileSyntax
  
  init(file: String, tree: SourceFileSyntax) {
    self.file = file
    self.tree = tree
  }
  
  func buildScope() throws -> TopLevelScope {
    let buildScope = try BuildScope(file: file, tree: tree)
    buildScope.walk(buildScope.tree)
    return buildScope.topLevel
  }
  
}

private class BuildScope: SyntaxVisitor {
  
  enum Level: CustomStringConvertible {
    
    case name(Name)
    
    case subScope(SubScope)
    
    case transaction(Transaction)
    
    case topLevel(TopLevelScope)
    
    var name: Name {
      guard case let .name(name) = self else {
        preconditionFailure()
      }
      return name
    }
    
    var subScope: SubScope {
      guard case let .subScope(subScope) = self else {
        preconditionFailure()
      }
      return subScope
    }
    
    var transaction: Transaction {
      guard case let .transaction(transaction) = self else {
        preconditionFailure()
      }
      return transaction
    }
    
    var scope: Scope {
      switch self {
      case let .subScope(subScope): return subScope
      case let .topLevel(topLevel): return topLevel
      default:
        preconditionFailure()
      }
    }
    
    var asTransaction: Transaction? {
      guard case let .transaction(transaction) = self else {
        return nil
      }
      return transaction
    }
    
    var description: String {
      switch self {
      case .name(let name):               return name.description
      case .topLevel(let topLevel):       return topLevel.description
      case .subScope(let subScope):       return subScope.description
      case .transaction(let transaction): return transaction.description
      }
    }
    
  }
  
  let file: String
  
  let tree: SourceFileSyntax
  
  let slc: SourceLocationConverter
  
  private(set) var stack: [Level]
  
  let topLevel: TopLevelScope
  
  init(file: String, tree: SourceFileSyntax) throws {
    self.file = file
    self.tree = tree
    self.slc = SourceLocationConverter(file: file, tree: tree)
    let topLevel = TopLevelScope()
    self.topLevel = topLevel
    self.stack = [.topLevel(topLevel)]
  }
  
  var top: Level {
    stack[stack.count - 1]
  }
  
  private func push(_ name: Name) {
    self.stack.append(.name(name))
    Logger.scopeBuilder.info("[\(Self.self)] [\(#function)] name = \(name)")
  }
  
  private func push(_ subScope: SubScope) {
    self.stack.append(.subScope(subScope))
    Logger.scopeBuilder.info("[\(Self.self)] [\(#function)] subScope = \(subScope)")
  }
  
  private func push(_ transaction: Transaction) {
    self.stack.append(.transaction(transaction))
    Logger.scopeBuilder.info("[\(Self.self)] [\(#function)] transaction = \(transaction)")
  }
  
  // Returns attached object
  @discardableResult
  private func pop() -> Level {
    let popped = stack.removeLast()
    Logger.scopeBuilder.info("[\(Self.self)] [\(#function)] popped = \(popped); top = \(self.top)")
    return popped
  }
  
  // MARK: Types
  
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    let name = Name(
      scope: top.scope,
      syntaxID: node.id,
      identifier: ScoppedIdentifier(
        isStatic: false,
        name: node.identifier.text
      ),
      kind: .type,
      sourceRange: node.sourceRange(converter: slc)
    )
    push(name)
    return super.visit(node)
  }
  
  override func visitPost(_ node: StructDeclSyntax) {
    super.visitPost(node)
    let popped = pop().name
    popped.scope.addName(popped)
  }
  
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    let name = Name(
      scope: top.scope,
      syntaxID: node.id,
      identifier: ScoppedIdentifier(
        isStatic: false,
        name: node.identifier.text
      ),
      kind: .type,
      sourceRange: node.sourceRange(converter: slc))
    push(name)
    return super.visit(node)
  }
  
  override func visitPost(_ node: ClassDeclSyntax) {
    super.visitPost(node)
    let popped = pop().name
    popped.scope.addName(popped)
  }
  
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    let name = Name(
      scope: top.scope,
      syntaxID: node.id,
      identifier: ScoppedIdentifier(
        isStatic: false,
        name: node.identifier.text
      ),
      kind: .type,
      sourceRange: node.sourceRange(converter: slc)
    )
    push(name)
    return super.visit(node)
  }
  
  override func visitPost(_ node: EnumDeclSyntax) {
    super.visitPost(node)
    let popped = pop().name
    popped.scope.addName(popped)
  }
  
  override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
    let name = Name(
      scope: top.scope,
      syntaxID: node.id,
      identifier: ScoppedIdentifier(
        isStatic: false,
        name: node.identifier.text
      ),
      kind: .type,
      sourceRange: node.sourceRange(converter: slc)
    )
    push(name)
    return super.visit(node)
  }
  
  override func visitPost(_ node: ProtocolDeclSyntax) {
    super.visitPost(node)
    let popped = pop().name
    popped.scope.addName(popped)
  }
  
  // MARK: Extension
  
  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    let name = Name(
      scope: top.scope,
      syntaxID: node.id,
      identifier: ScoppedIdentifier(
        isStatic: false,
        name: node.extendedType.description
      ),
      kind: .extension,
      sourceRange: node.sourceRange(converter: slc)
    )
    push(name)
    return super.visit(node)
  }
  
  override func visitPost(_ node: ExtensionDeclSyntax) {
    super.visitPost(node)
    let popped = pop().name
    popped.scope.addName(popped)
  }
  
  // MARK: Non-Types
  
  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    let name = Name(
      scope: top.scope,
      syntaxID: node.id,
      identifier: ScoppedIdentifier(
        isStatic: node.modifiers?.containsStaticOrClass == true ,
        name: node.identifier.text
      ),
      kind: .function,
      sourceRange: node.sourceRange(converter: slc)
    )
    push(name)
    return super.visit(node)
  }
  
  override func visitPost(_ node: FunctionDeclSyntax) {
    super.visitPost(node)
    let popped = pop().name
    popped.scope.addName(popped)
  }
  
  override func visit(_ node: EnumCaseElementSyntax) -> SyntaxVisitorContinueKind {
    let name = Name(
      scope: top.scope,
      syntaxID: node.id,
      identifier: ScoppedIdentifier(
        isStatic: true,
        name: node.identifier.text
      ),
      kind: .enumCase,
      sourceRange: node.sourceRange(converter: slc)
    )
    push(name)
    return super.visit(node)
  }
  
  override func visitPost(_ node: EnumCaseElementSyntax) {
    super.visitPost(node)
    let enumCase = pop().name
    enumCase.scope.addName(enumCase)
  }
  
  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    let transaction = VariableTransaction(
      scope: top.scope,
      isStatic: node.modifiers?.containsStaticOrClass == true
    )
    push(transaction)
    return super.visit(node)
  }
  
  override func visitPost(_ node: VariableDeclSyntax) {
    super.visitPost(node)
    let popped = pop().transaction as! VariableTransaction
    for name in popped.names {
      popped.scope.addName(name)
    }
  }
  
  // MARK: Pattern Binding
  
  override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
    if let transaction = top.asTransaction as? VariableTransaction {
      push(PatternBindingTransaction(variable: transaction))
    } else {
      notImplemented()
    }
    return super.visit(node)
  }
  
  override func visitPost(_ node: PatternBindingSyntax) {
    super.visitPost(node)
    let popped = unsafeDowncast(pop().transaction, to: PatternBindingTransaction.self)
    let name = popped.identifier!
    popped.getter.map(name.addSubScope)
    popped.setter.map(name.addSubScope)
    popped.variable.appendName(name)
  }
  
  override func visit(_ node: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
    if let binding = top.asTransaction as? PatternBindingTransaction {
      let name = Name(
        scope: binding.variable.scope,
        syntaxID: node.id,
        identifier: ScoppedIdentifier(
          isStatic: binding.variable.isStatic,
          name: node.identifier.text
        ),
        kind: .variable,
        sourceRange: node.sourceRange(converter: slc)
      )
      push(name)
    } else {
      notImplemented()
    }
    return super.visit(node)
  }
  
  override func visitPost(_ node: IdentifierPatternSyntax) {
    super.visitPost(node)
    let poppedName = pop().name
    if let binding = top.asTransaction as? PatternBindingTransaction {
      binding.append(.name(poppedName))
    }
  }
  
  // MARK: Scopes
  
  override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
    let scope: SubScope
    let name: Name
    if let transaction = top.asTransaction as? PatternBindingTransaction {
      name = transaction.identifier!
    } else {
      name = top.name
    }
    scope = SubScope(parent: name, options: ScopeOptions(name.kind))
    push(scope)
    return super.visit(node)
  }
  
  override func visitPost(_ node: CodeBlockSyntax) {
    super.visitPost(node)
    let poppedScope = pop().subScope
    if let binding = top.asTransaction as? PatternBindingTransaction {
      binding.append(.subScope(poppedScope))
    }
  }
  
  override func visit(_ node: MemberDeclBlockSyntax) -> SyntaxVisitorContinueKind {
    let parent = top.name
    let scope = SubScope(parent: parent, options: ScopeOptions(parent.kind))
    push(scope)
    return super.visit(node)
  }
  
  override func visitPost(_ node: MemberDeclBlockSyntax) {
    super.visitPost(node)
    let popped = pop().subScope
    popped.parent.addSubScope(popped)
  }
  
}

extension ModifierListSyntax {
  
  fileprivate var containsStaticOrClass: Bool {
    self.contains { decl in
      decl.firstToken?.tokenKind == .staticKeyword ||
      decl.firstToken?.tokenKind == .classKeyword
    }
  }
  
}

extension Logger {
  
  fileprivate static let scopeBuilder = Logger(subsystem: "com.WeZZardDesign.Swift-COW-Refactorer", category: "ScopeBuilder")
  
}
