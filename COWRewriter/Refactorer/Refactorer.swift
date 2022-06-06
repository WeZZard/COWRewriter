//
//  Refactorer.swift
//  COWRewriter
//
//  Created by WeZZard on 5/25/22.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxParser

struct RefactorableDecl: Hashable {
  
  let treeID: UInt
  
  let identifier: String
  
  let sourceRange: SourceRange
  
  let suggestedStorageClassName: String
  
  let suggestedStorageVariableName: String
  
  let suggestedMakeUniqueStorageFunctionName: String
  
  /// COW refactoring based on pattern binding's type.
  let uninferrablePatternBindings: [UninferrablePatternBinding]
  
}

/// Pattern bindings that cannot infer its type.
struct UninferrablePatternBinding: Hashable {
  
  let treeID: UInt
  
  /// The identifier for the error type in the context.
  let id: UInt
  
  let letOrVar: String
  
  let identifier: String
  
  let startLocation: SourceLocation
  
  let endLocation: SourceLocation
  
  let maybeType: TypeSyntax?
  
}

struct RefactorRequest: Equatable {
  
  let decl: RefactorableDecl
  
  let storageClassName: String
  
  let storageVariableName: String
  
  let makeUniqueStorageFunctionName: String
  
  let typedefs: [String : TypeSyntax]
  
}

final class Refactorer: Equatable {
  
  private let target: Target
  
  private let file: String?
  
  private let tree: Syntax
  
  private let slc: SourceLocationConverter
  
  private let treeID: UInt
  
  @inlinable
  var refactorableDecls: [RefactorableDecl] {
    get async {
      if let decls = _refactorableDecls_ {
        return decls
      }
      
      class Context: SemaInputting, SemaOutputting {
        
        let refactorer: Refactorer
        
        var tree: Syntax
        
        let treeID: UInt
        
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
  func refactor(_ requests: [RefactorRequest]) async -> Syntax {
    
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
      
      func rewriter(_ sender: COWRewriter, shouldRewriteDeclFrom startLocation: SourceLocation, to endLocation: SourceLocation) -> Bool {
        refactorableDecls.contains { each in
          each.sourceRange.start == startLocation && each.sourceRange.end == endLocation
        }
      }
      
    }
    
    let context = await Context(refactorer: self)
    let rewriter = COWRewriter(input: context)
    return rewriter.execute(requests: requests)
  }
  
  @inlinable
  init(target: Target, file: String, tree: SourceFileSyntax) {
    self.target = target
    self.file = file
    self.tree = Syntax(tree)
    self.slc = SourceLocationConverter(file: file, tree: tree)
    self._refactorableDecls_ = nil
    self.treeID = UInt.random(in: .min...(.max))
  }
  
  enum InitializationError: Error, CustomStringConvertible {
    
    case notFileUrl(URL)
    
    case parserError(URL, Error)
    
    var description: String {
      switch self {
      case let .notFileUrl(url):
        return "\(url) is not a file URL."
      case let .parserError(url, error):
        return "Error happened during parsing Swift source at \(url): \(error.localizedDescription)"
      }
    }
    
  }
  
  convenience init(url: URL) throws {
    guard url.isFileURL else {
      throw InitializationError.notFileUrl(url)
    }
    
    do {
      let tree = try SyntaxParser.parse(url)
      let file = url.absoluteURL.path
      self.init(target: .host, file: file, tree: tree)
    } catch let error {
      throw InitializationError.parserError(url, error)
    }
  }
  
  static func == (lhs: Refactorer, rhs: Refactorer) -> Bool {
    return lhs === rhs
  }
  
  // MARK: Backwarded Properties
  
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
