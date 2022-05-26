//
//  Sema.swift
//  COWRewriter
//
//  Created by WeZZard on 5/26/22.
//

import Foundation
import SwiftSyntax


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
  
  unowned let input: SemaInputting
  
  unowned let output: SemaOutputting
  
  private var hasPerformed: Bool
  
  init(input: SemaInputting, output: SemaOutputting) {
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
      tree: input.tree,
      slc: input.slc
    )
    let typeCheckedTree = typeChecker.check()
    let detector = RefactorableDeclsDetector(
      tree: typeCheckedTree,
      slc: input.slc
    )
    output.refactorableDecls = detector.detect()
  }

}


private class TypeChecker: SyntaxRewriter {
  
  let tree: Syntax
  
  let slc: SourceLocationConverter
  
  private var result: Syntax?
  
  init(tree: Syntax, slc: SourceLocationConverter) {
    self.tree = tree
    self.slc = slc
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
