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
  
  var tree: SourceFileSyntax { get }
  
  var treeID: UInt { get }
  
  var slc: SourceLocationConverter { get }
  
}


protocol SemaOutputting: AnyObject {
  
  var tree: SourceFileSyntax { get set }
  
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
    let detector = SimpleRefactorableDeclsDetector(
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


private class SimpleRefactorableDeclsDetector: SyntaxVisitor {
  
  struct UntyppedBinding {
    
    let letOrVar: String
    
    let identifier: String
    
    let sourceRange: SourceRange
    
  }
  
  let treeID: UInt
  
  let tree: SourceFileSyntax
  
  let slc: SourceLocationConverter
  
  private var hasDetected: Bool
  
  private var structDeclSyntaxs: [StructDeclSyntax]
  
  private var refactorableDecls: [RefactorableDecl]
  
  init(treeID: UInt, tree: SourceFileSyntax, slc: SourceLocationConverter) {
    self.treeID = treeID
    self.tree = tree
    self.slc = slc
    self.hasDetected = false
    self.structDeclSyntaxs = []
    self.refactorableDecls = []
  }
  
  func detect() -> [RefactorableDecl] {
    if hasDetected {
      return refactorableDecls
    }
    walk(tree)
    update(structDeclSyntaxs)
    hasDetected = true
    return refactorableDecls
  }
  
  override func visitPost(_ node: StructDeclSyntax) {
    super.visitPost(node)
    structDeclSyntaxs.append(node)
  }
  
  private struct SuggestedStorageNamings {
    
    var storageClassName: String
    
    var storageVariableName: String
    
    var storageUniquificationFunctionName: String
    
    init() {
      storageClassName = "Storage"
      storageVariableName = "storage"
      storageUniquificationFunctionName = "makeUniqueStorageIfNeeded"
    }
    
  }
  
  private func makeStorageRelatedUnresolvedSemanticsIssues(
    for structDecl: StructDeclSyntax
  ) -> ([UnresolvedSemantics], [NamingKey : String]) {
    typealias Names = (
      instanceVariableNames: Set<String>,
      instanceFunctionNames: Set<String>,
      subTypeNames: Set<String>
    )
    let (
      instanceVariableNames,
      instanceFunctionNames,
      subTypeNames
    ) = structDecl.members.members.reduce(([], [], [])) { partial, each -> Names in
      var (instanceVariableNames, instanceFunctionNames,subTypeNames) = partial
      if let varDecl = each.decl.as(VariableDeclSyntax.self) {
        let isStatic = varDecl.modifiers?.contains(where: { $0.name == .static }) == true
        for binding in varDecl.bindings {
          guard let idPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            return (instanceVariableNames, instanceFunctionNames, subTypeNames)
          }
          if !isStatic {
            instanceVariableNames.insert(idPattern.identifier.withoutTrivia().text)
          }
        }
      } else if let funcDecl = each.decl.as(FunctionDeclSyntax.self) {
        if !(funcDecl.modifiers?.contains(where: { $0.name == .static }) == true) {
          instanceFunctionNames.insert(funcDecl.identifier.withoutTrivia().text)
        }
      } else if let structDecl = each.decl.as(StructDeclSyntax.self) {
        subTypeNames.insert(structDecl.identifier.withoutTrivia().text)
      } else if let enumDecl = each.decl.as(EnumDeclSyntax.self) {
        subTypeNames.insert(enumDecl.identifier.withoutTrivia().text)
      } else if let classDecl = each.decl.as(ClassDeclSyntax.self) {
        subTypeNames.insert(classDecl.identifier.withoutTrivia().text)
      }
      return (instanceVariableNames, instanceFunctionNames, subTypeNames)
    }
    
    func resolveName(_ name: String, with existedNames: Set<String>)
    -> (
      resolvedName: String,
      conflictCount: Int
    ) {
      var conflistCount = 0
      var resolvedName = name
      while existedNames.contains(resolvedName) {
        resolvedName = "\(name)\(conflistCount + 1)"
        conflistCount += 1
      }
      return (resolvedName, conflistCount)
    }
    
    var suggestedNamings = [NamingKey : String]()
    suggestedNamings[.storageClassName] = "Storage"
    suggestedNamings[.storageVariableName] = "storage"
    suggestedNamings[.storageUniquificationFunctionName] = "makeUniqueStorageIfNeeded"
    
    typealias Item = (key: NamingKey, existedNames: Set<String>)
    
    let items: [Item] = [
      (.storageClassName, subTypeNames),
      (.storageVariableName, instanceVariableNames),
      (.storageUniquificationFunctionName, instanceFunctionNames),
    ]
    
    let sourceRange = structDecl.sourceRange(converter: slc)
    
    let unresolvedSemantics = items.compactMap {
      (key, existednames) -> UnresolvedSemantics? in
      let name = suggestedNamings[key]!
      let (resolvedName, conflictsCount) = resolveName(name, with: existednames)
      if conflictsCount == 0 {
        return nil
      }
      suggestedNamings[key] = resolvedName
      return .name(
        .init(
          treeID: treeID,
          sourceRange: sourceRange,
          id: UInt(sourceRange: sourceRange, key: key),
          key: key,
          suggestedName: resolvedName
        )
      )
    }
    
    return (unresolvedSemantics, suggestedNamings)
  }
  
  private func makeTypeAnnotationIssues(
    for structDeclSyntax: StructDeclSyntax
  ) -> [UnresolvedSemantics] {
    var untyppedBindings = [UnresolvedSemantics]()
    for eachMember in structDeclSyntax.members.members {
      if let varDecl = eachMember.decl.as(VariableDeclSyntax.self) {
        for binding in varDecl.bindings {
          guard let idPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            continue
          }
          if binding.typeAnnotation == nil {
            let sourceRange = binding.sourceRange(converter: slc)
            untyppedBindings.append(
              .typeAnnotation(
                UnresolvedSemantics.TypeAnnotationIssue(
                  treeID: treeID,
                  sourceRange: sourceRange,
                  id: UInt(sourceRange: sourceRange),
                  letOrVar: varDecl.letOrVarKeyword == .let ? "let" : "var",
                  identifier: idPattern.identifier.withoutTrivia().text,
                  maybeType: nil
                )
              )
            )
          }
        }
      }
    }
    return untyppedBindings
  }
  
  private func update(_ syntaxes: [StructDeclSyntax]) {
    guard syntaxes.count > 0 else {
      return
    }
    
    self.refactorableDecls = syntaxes.compactMap { decl in
      
      guard decl.members.members.storedVariables.count > 0 else {
        return nil
      }
      
      let (storageIssues, storageNamingSuggestions) = makeStorageRelatedUnresolvedSemanticsIssues(for: decl)
      
      let typeIssues = makeTypeAnnotationIssues(for: decl)
      
      return RefactorableDecl(
        treeID: treeID,
        identifier: decl.identifier.withoutTrivia().text,
        sourceRange: decl.sourceRange(converter: slc),
        namingSuggestions: storageNamingSuggestions,
        unresolvedSemantics: typeIssues + storageIssues
      )
    }
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


extension UInt {
  
  @inline(__always)
  fileprivate init<Key: Hashable>(sourceRange: SourceRange, key: Key?) {
    self.init(
      startLocation: sourceRange.start,
      endLocation: sourceRange.end,
      key: key
    )
  }
  
  @inline(__always)
  fileprivate init<Key: Hashable>(
    startLocation: SourceLocation,
    endLocation: SourceLocation,
    key: Key?
  ) {
    self.init(
      startOffset: startLocation.offset,
      endOffset: endLocation.offset,
      key: key
    )
  }
  
  @inline(__always)
  fileprivate init<Key: Hashable>(startOffset: Int, endOffset: Int, key: Key?) {
    var hasher = Hasher()
    hasher.combine(startOffset)
    hasher.combine(endOffset)
    if let key = key {
      hasher.combine(key)
    }
    self = UInt(bitPattern: hasher.finalize())
  }
  
  @inline(__always)
  fileprivate init(sourceRange: SourceRange) {
    self.init(startLocation: sourceRange.start, endLocation: sourceRange.end)
  }
  
  @inline(__always)
  fileprivate init(startLocation: SourceLocation, endLocation: SourceLocation) {
    self.init(startOffset: startLocation.offset, endOffset: endLocation.offset)
  }
  
  @inline(__always)
  fileprivate init(startOffset: Int, endOffset: Int) {
    var hasher = Hasher()
    hasher.combine(startOffset)
    hasher.combine(endOffset)
    self = UInt(bitPattern: hasher.finalize())
  }
  
}
