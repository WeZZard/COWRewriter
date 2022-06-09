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
  
  let namingSuggestions: [NamingKey : String]
  
  let unresolvedSemantics: [UnresolvedSemantics]
  
}

enum UnresolvedSemantics: Hashable {
  
  case name(NamingIssue)
  
  case typeAnnotation(TypeAnnotationIssue)
  
  @inlinable
  var treeID: UInt {
    switch self {
    case let .name(issue):            return issue.treeID
    case let .typeAnnotation(issue):  return issue.treeID
    }
  }
  
  @inlinable
  var sourceRange: SourceRange {
    switch self {
    case let .name(issue):            return issue.sourceRange
    case let .typeAnnotation(issue):  return issue.sourceRange
    }
  }
  
  /// The identifier for the error type in the context.
  @inlinable
  var id: UInt {
    switch self {
    case let .name(issue):            return issue.id
    case let .typeAnnotation(issue):  return issue.id
    }
  }
  
  struct NamingIssue: Hashable {
    
    typealias Key = NamingKey
    
    let treeID: UInt
    
    let sourceRange: SourceRange
    
    /// The identifier for the error type in the context.
    let id: UInt
    
    let key: NamingKey
    
    let suggestedName: String?
    
  }
  
  /// Pattern bindings that cannot infer its type.
  ///
  /// - Note: COW refactoring based on pattern binding's type.
  ///
  struct TypeAnnotationIssue: Hashable {
    
    let treeID: UInt
    
    let sourceRange: SourceRange
    
    /// The identifier for the error type in the context.
    let id: UInt
    
    let letOrVar: String
    
    let identifier: String
    
    let maybeType: TypeSyntax?
    
  }
  
  
}

struct NamingKey: RawRepresentable, Hashable {
  
  typealias RawValue = String
  
  var rawValue: RawValue
  
  init(rawValue: String) {
    self.rawValue = rawValue
  }
  
  static let storageClassName = NamingKey(rawValue: "Storage Class Name")
  
  static let storageVariableName = NamingKey(rawValue: "Storage Variable Name")
  
  static let storageUniquificationFunctionName = NamingKey(rawValue: "Storage Uniquification Function Name")
  
}

struct RefactorRequest: Equatable {
  
  let decl: RefactorableDecl
  
  let storageClassName: String
  
  let storageVariableName: String
  
  let storageUniquificationFunctionName: String
  
  let typedefs: [String : TypeSyntax]
  
}

final class Refactorer: Equatable {
  
  private let target: Target
  
  private let file: String?
  
  private let tree: SourceFileSyntax
  
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
        
        var tree: SourceFileSyntax
        
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
  func refactor(_ requests: [RefactorRequest]) async -> SourceFileSyntax {
    
    class Context: COWRewriterInputContext {
      
      let file: String?
      
      var tree: SourceFileSyntax
      
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
    self.tree = tree
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
