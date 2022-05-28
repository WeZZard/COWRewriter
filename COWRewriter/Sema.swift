//
//  Sema.swift
//  COWRewriter
//
//  Created by WeZZard on 5/26/22.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

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
  
  var treeID: UUID { get }
  
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
    let typeChecker = TypeChecker(
      target: target,
      tree: input.tree,
      slc: input.slc
    )
    let typeCheckedTree = typeChecker.check()
    let detector = RefactorableDeclsDetector(
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
  
  let tree: Syntax
  
  let slc: SourceLocationConverter
  
  private var decls: [RefactorableDecl]
  
  private var hasDetected: Bool
  
  init(tree: Syntax, slc: SourceLocationConverter) {
    self.tree = tree
    self.slc = slc
    self.decls = []
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
  
}
