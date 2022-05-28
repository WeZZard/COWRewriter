//
//  Refactorer.swift
//  COWRewriter
//
//  Created by WeZZard on 5/25/22.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxParser

typealias DetailedExprSyntax = DetailedSyntax<ExprSyntax>

typealias DetailedDecl = DetailedSyntax<DeclSyntax>

typealias DetailedPatternBindingSyntax = DetailedSyntax<PatternBindingSyntax>

struct DetailedSyntax<SyntaxType: SyntaxProtocol> {
  
  let syntax: SyntaxType
  
  let startLocation: SourceLocation
  
  let endLocation: SourceLocation
  
}

struct RefactorableDecl {
  
  let treeID: UUID
  
  let decl: DetailedDecl
  
  /// COW refactoring based on pattern binding's type.
  let uninferrablePatternBindings: [UninferrablePatternBinding]
  
}

/// Pattern bindings that cannot infer its type.
struct UninferrablePatternBinding {
  
  /// The identifier for the error type in the context.
  let identifier: UUID
  
  let patternBindingSyntax: DetailedPatternBindingSyntax
  
  let treeID: UUID
  
  let maybeType: String?
  
}

struct RefactorRequest {
  
  let decls: [RefactorableDecl]
  
  let typedefs: [UUID : String]
  
}

final class Refactorer {
  
  private let target: Target
  
  private let file: String?
  
  private let tree: Syntax
  
  private let slc: SourceLocationConverter
  
  private let treeID: UUID
  
  @inlinable
  var refactorableDecls: [RefactorableDecl] {
    get async {
      if let decls = _refactorableDecls_ {
        return decls
      }
      
      class Context: SemaInputting, SemaOutputting {
        
        let refactorer: Refactorer
        
        var tree: Syntax
        
        let treeID: UUID
        
        var refactorableDecls: [RefactorableDecl]
        
        @inline(__always)
        var slc: SourceLocationConverter {
          _read {
            yield refactorer.slc
          }
        }
        
        @inline(__always)
        init(refactorer: Refactorer) {
          self.refactorer = refactorer
          self.tree = refactorer.tree
          self.treeID = refactorer.treeID
          self.refactorableDecls = []
        }
        
      }
      
      let context = Context(refactorer: self)
      let sema = Sema(target: target, input: context, output: context)
      sema.performIfNeeded()
      _refactorableDecls_ = context.refactorableDecls
      return context.refactorableDecls
    }
  }
  
  @inlinable
  func refactor(_ request: RefactorRequest) async -> Syntax {
    
    class Context: COWRewriterInputContext {
      
      let file: String?
      
      var tree: Syntax
      
      let slc: SourceLocationConverter
      
      let refactorableDecls: [RefactorableDecl]
      
      @inline(__always)
      init(refactorer: Refactorer) async {
        self.file = refactorer.file
        self.tree = refactorer.tree
        self.slc = refactorer.slc
        self.refactorableDecls = await refactorer.refactorableDecls
      }
      
    }
    
    let context = await Context(refactorer: self)
    let rewriter = COWRewriter(input: context)
    return rewriter.execute(request: request)
  }
  
  @inlinable
  init(target: Target, file: String, tree: SourceFileSyntax) {
    self.target = target
    self.file = file
    self.tree = Syntax(tree)
    self.slc = SourceLocationConverter(file: file, tree: tree)
    self._refactorableDecls_ = nil
    self.treeID = UUID()
  }
  
  private var _refactorableDecls_: [RefactorableDecl]?
  
}

extension Refactorer {
  
  @inlinable
  convenience init?(target: Target, source: String) async {
    guard let tree = try? SyntaxParser.parse(source: source) else {
      return nil
    }
    self.init(target: target, file: "SOURCE_IN_MEMORY", tree: tree)
  }
  
  @inlinable
  convenience init?(target: Target, url: URL) async {
    guard let tree = try? SyntaxParser.parse(url) else {
      return nil
    }
    self.init(target: target, file: url.path, tree: tree)
  }
  
  @inlinable
  convenience init?(target: Target, path: String) async {
    await self.init(target: target, url: URL(fileURLWithPath: path))
  }
  
}
