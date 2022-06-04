//
//  Sema.swift
//  COWRewriter
//
//  Created by WeZZard on 5/26/22.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftUI

enum Target {
  
  case of32Bit
  
  case of64Bit
  
  static var host: Target {
#if arch(x86_64) || arch(arm64)
    return .of64Bit
#else
    return .of32Bit
#endif
  }

}

protocol SemaInputting: AnyObject {
  
  var tree: Syntax { get }
  
  var treeID: UInt { get }
  
  var slc: SourceLocationConverter { get }
  
}


protocol SemaOutputting: AnyObject {
  
  var tree: Syntax { get set }
  
  var refactorableDecls: [RefactorableDecl] { get set }
  
}

/// A simple semantic analyzing process
///
/// In this process, we do:
/// - Inferring missing types.
/// - Collect refactorable decls.
///
class Sema {
  
  let target: Target
  
  unowned let input: SemaInputting
  
  unowned let output: SemaOutputting
  
  private var hasPerformed: Bool
  
  init(target: Target, input: SemaInputting, output: SemaOutputting) {
    self.target = target
    self.input = input
    self.output = output
    self.hasPerformed = false
  }
  
  func performIfNeeded() {
    if !hasPerformed {
      perform()
      hasPerformed = false
    }
  }
  
  @inline(__always)
  private func perform() {
    /*
    let typeChecker = TypeChecker(
      target: target,
      tree: input.tree,
      slc: input.slc
    )
     */
    let typeCheckedTree = input.tree // FIXME: typeChecker.check()
    let detector = RefactorableDeclsDetector(
      treeID: input.treeID,
      tree: typeCheckedTree,
      slc: input.slc
    )
    output.tree = typeCheckedTree
    output.refactorableDecls = detector.detect()
  }

}


private class LiteralResolvingContext {
  
  let target: Target
  
  init(target: Target) {
    self.target = target
  }
  
}

// FIXME: Crashes when type checking XML files with .swift extension.

/// Currently only support type inferring for limited literal initializing of
/// variable bindings.
private class TypeChecker: SyntaxRewriter {
  
  class Scope {
    
    enum LiteralType {
      
      case string
      
      case integer
      
      case boolean
      
      case float
      
      func resolvedName(context: LiteralResolvingContext) -> String {
        switch self {
        case .string:     return "String"
        case .integer:    return "Int"
        case .boolean:    return "Bool"
        case .float:
          switch context.target {
          case .of32Bit:  return "Float"
          case .of64Bit:  return "Double"
          }
        }
      }
      
    }
    
    var isInInitializerClause: Bool
    
    var initialzerLiteral: LiteralType?
    
    init() {
      isInInitializerClause = false
      initialzerLiteral = nil
    }
    
  }
  
  var scopes: [Scope]
  
  let tree: Syntax
  
  let slc: SourceLocationConverter
  
  private var result: Syntax?
  
  let target: Target
  
  private let context: LiteralResolvingContext
  
  init(target: Target, tree: Syntax, slc: SourceLocationConverter) {
    self.target = target
    self.scopes = []
    self.tree = tree
    self.slc = slc
    self.context = LiteralResolvingContext(target: target)
  }
  
  func check() -> Syntax {
    if let result = result {
      return result
    }
    var inputTree = tree
    var outputTree: Syntax
    repeat {
      outputTree = visit(inputTree)
      inputTree = outputTree
    } while inputTree != outputTree
    result = outputTree
    return outputTree
  }
  
  override func visit(_ node: InitializerClauseSyntax) -> Syntax {
    scopes.last!.isInInitializerClause = true
    let result = super.visit(node)
    scopes.last!.isInInitializerClause = false
    return result
  }
  
  override func visit(_ node: PatternBindingSyntax) -> Syntax {
    scopes.append(Scope())
    let result = super.visit(node)
    let popped = scopes.removeLast()
    if let literal = popped.initialzerLiteral, node.typeAnnotation == nil {
      var typeAnnotatedNode = node
      typeAnnotatedNode.typeAnnotation = TypeAnnotationSyntax { builder in
        builder.useColon(.colon)
        builder.useType(TypeSyntax(SimpleTypeIdentifierSyntax { id in
          id.useName(.identifier(literal.resolvedName(context: context)))
        }))
      }
      return Syntax(typeAnnotatedNode)
    }
    return result
  }
  
  override func visit(_ node: OptionalBindingConditionSyntax) -> Syntax {
    scopes.append(Scope())
    let result = super.visit(node)
    let popped = scopes.removeLast()
    if let literal = popped.initialzerLiteral, node.typeAnnotation == nil {
      var typeAnnotatedNode = node
      typeAnnotatedNode.typeAnnotation = TypeAnnotationSyntax { builder in
        builder.useColon(.colon)
        builder.useType(TypeSyntax(SimpleTypeIdentifierSyntax { id in
          id.useName(.identifier(literal.resolvedName(context: context)))
        }))
      }
      return Syntax(typeAnnotatedNode)
    }
    return result
  }
  
  override func visit(_ node: FloatLiteralExprSyntax) -> ExprSyntax {
    scopes.last!.initialzerLiteral = .float
    return super.visit(node)
  }
  
  override func visit(_ node: StringLiteralExprSyntax) -> ExprSyntax {
    scopes.last!.initialzerLiteral = .string
    return super.visit(node)
  }
  
  override func visit(_ node: IntegerLiteralExprSyntax) -> ExprSyntax {
    scopes.last!.initialzerLiteral = .integer
    return super.visit(node)
  }
  
  override func visit(_ node: BooleanLiteralExprSyntax) -> ExprSyntax {
    scopes.last!.initialzerLiteral = .boolean
    return super.visit(node)
  }
  
}


private class RefactorableDeclsDetector: SyntaxVisitor {
  
  class Scope {
    
    var subscopes: [Scope]
    
    init() {
      self.subscopes = []
    }
    
    var parent: Scope? {
      fatalError()
    }
    
    func addScope(_ scope: Scope) {
      subscopes.append(scope)
    }
    
  }
  
  class TopLevel: Scope {
    
    override var parent: Scope? {
      nil
    }
    
  }
  
  class StructScope: Scope {
    
    private unowned let _parent: Scope
    
    let identifier: String
    
    let startLocation: SourceLocation
    
    let endLocation: SourceLocation
    
    init(
      parent: Scope,
      identifier: String,
      startLocation: SourceLocation,
      endLocation: SourceLocation
    ) {
      self._parent = parent
      self.identifier = identifier
      self.startLocation = startLocation
      self.endLocation = endLocation
    }
    
    override var parent: Scope? {
      _parent
    }
    
    var storedPropertiesCount: Int {
      subscopes.reduce(0) { partial, each in
        guard let varScope = each as? VariableScope else {
          return partial
        }
        return varScope.storageBackwardedBindingsCount + partial
      }
    }
    
    var untyppedBindings: [UntyppedBinding] {
      subscopes.compactMap { each -> [UntyppedBinding]? in
        guard let varScope = each as? VariableScope else {
          return nil
        }
        return varScope.untyppedBindings
      }.flatMap({$0})
    }
    
  }
  
  class VariableScope: Scope {
    
    private unowned let _parent: Scope
    
    let usesLetKeyword: Bool
    
    init(parent: Scope, usesLetKeyword: Bool) {
      self._parent = parent
      self.usesLetKeyword = usesLetKeyword
    }
    
    override var parent: Scope? {
      _parent
    }
    
    var storageBackwardedBindingsCount: Int {
      subscopes.filter { each in
        (each as? BindingScope)?.isStored == true
      }.count
    }
    
    var untyppedBindings: [UntyppedBinding] {
      subscopes.compactMap { each in
        guard let binding = each as? BindingScope else {
          return nil
        }
        guard binding.type == nil else {
          return nil
        }
        return (
          binding.letOrVar,
          binding.identifier,
          binding.startLocation,
          binding.endLocation
        )
      }
    }
    
  }
  
  class BindingScope: Scope {
    
    private unowned let _parent: Scope
    
    let letOrVar: String
    
    let identifier: String
    
    let startLocation: SourceLocation
    
    let endLocation: SourceLocation
    
    let type: String?
    
    let isStored: Bool
    
    init(
      parent: Scope,
      letOrVar: String,
      identifier: String,
      startLocation: SourceLocation,
      endLocation: SourceLocation,
      type: String?,
      isStored: Bool
    ) {
      self._parent = parent
      self.letOrVar = letOrVar
      self.identifier = identifier
      self.startLocation = startLocation
      self.endLocation = endLocation
      self.type = type
      self.isStored = isStored
    }
    
    override var parent: Scope? {
      _parent
    }
    
  }
  
  typealias UntyppedBinding = (
    letOrVar: String,
    identifier: String,
    startLocation: SourceLocation,
    endLocation: SourceLocation
  )
  
  let treeID: UInt
  
  let tree: Syntax
  
  let slc: SourceLocationConverter
  
  private var decls: [RefactorableDecl]
  
  private var hasDetected: Bool
  
  private var rootScope: TopLevel
  
  private unowned var _topScope: Scope
  
  func topScope<T: Scope>() -> T {
    return unsafeDowncast(_topScope, to: T.self)
  }
  
  func mayBeTopScope<T: Scope>() -> T? {
    return _topScope as? T
  }
  
  func pushScope(_ scope: Scope) {
    _topScope.addScope(scope)
    _topScope = scope
  }
  
  @discardableResult
  func popScope<T: Scope>() -> T {
    let popped = _topScope
    _topScope = _topScope.parent!
    return unsafeDowncast(popped, to: T.self)
  }
  
  init(treeID: UInt, tree: Syntax, slc: SourceLocationConverter) {
    self.treeID = treeID
    self.tree = tree
    self.slc = slc
    self.decls = []
    let topLevel = TopLevel()
    self.rootScope = topLevel
    self._topScope = topLevel
    self.hasDetected = false
  }
  
  func detect() -> [RefactorableDecl] {
    if hasDetected {
      return decls
    }
    walk(tree)
    hasDetected = true
    return decls
  }
  
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    pushScope(
      StructScope(
        parent: topScope(),
        identifier: node.identifier.text,
        startLocation: node.startLocation(converter: slc),
        endLocation: node.endLocation(converter: slc)
      )
    )
    return super.visit(node)
  }
  
  override func visitPost(_ node: StructDeclSyntax) {
    super.visitPost(node)
    let topScope: StructScope = popScope()
    updateDecls(topScope)
  }
  
  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    pushScope(VariableScope(parent: topScope(), usesLetKeyword: node.usesLetKeyword))
    return super.visit(node)
  }
  
  override func visitPost(_ node: VariableDeclSyntax) {
    super.visitPost(node)
    popScope()
  }
  
  override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
    let parentVarScope = mayBeTopScope() as? VariableScope
    pushScope(
      BindingScope(
        parent: topScope(),
        letOrVar: parentVarScope?.usesLetKeyword == true ? "let" : "var",
        identifier: node.pattern.as(IdentifierPatternSyntax.self)!.identifier.text,
        startLocation: node.startLocation(converter: slc),
        endLocation: node.endLocation(converter: slc),
        type: node.typeAnnotation?.type.description,
        isStored: parentVarScope?.usesLetKeyword == true || node.hasStorage
      )
    )
    return super.visit(node)
  }
  
  override func visitPost(_ node: PatternBindingSyntax) {
    super.visitPost(node)
    popScope()
  }
  
  private func makeUninferrablePatternBinding(
    _ untyppedBinding: UntyppedBinding
  ) -> UninferrablePatternBinding {
    let (letOrVar, identifier, startLoc, endLoc) = untyppedBinding
    var hasher = Hasher()
    hasher.combine(startLoc.offset)
    hasher.combine(endLoc.offset)
    let id = UInt(bitPattern: hasher.finalize())
    return UninferrablePatternBinding(
      treeID: treeID,
      id: id,
      letOrVar: letOrVar,
      identifier: identifier,
      startLocation: startLoc,
      endLocation: endLoc,
      maybeType: nil
    )
  }
  
  private func updateDecls(_ scope: StructScope) {
    guard scope.storedPropertiesCount > 0 else {
      return
    }
    
    let decl = RefactorableDecl(
      treeID: treeID,
      identifier: scope.identifier,
      startLocation: scope.startLocation,
      endLocation: scope.endLocation,
      // FIXME: Need to be smart.
      suggestedStorageClassName: "Storage",
      // FIXME: Need to be smart.
      suggestedMakeUniqueStorageFunctionName: "makeUniqueStorageIfNeeded",
      uninferrablePatternBindings: scope.untyppedBindings.map(makeUninferrablePatternBinding)
    )
    
    decls.append(decl)
  }
  
}

extension VariableDeclSyntax {
  
  fileprivate var usesLetKeyword: Bool {
    if letOrVarKeyword.tokenKind == .letKeyword {
      return true
    }
    return false
  }
  
}


extension PatternBindingSyntax {
  
  fileprivate var hasStorage: Bool {
    accessor == nil
  }
  
}
