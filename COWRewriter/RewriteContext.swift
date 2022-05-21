//
//  RewriteContext.swift
//  COWRewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftSyntax
import SwiftSyntaxParser
import Foundation
import SwiftUI

internal struct RewritableDecl: Equatable, Hashable {
  
  fileprivate unowned var context: RewriteContext
  
  internal let name: String
  
  internal let startLocation: SourceLocation
  
  internal let endLocation: SourceLocation
  
  @inline(__always)
  internal static func == (lhs: RewritableDecl, rhs: RewritableDecl) -> Bool {
    return lhs.context === rhs.context &&
    lhs.name == rhs.name &&
    lhs.startLocation == rhs.startLocation &&
    lhs.endLocation == rhs.endLocation
  }
  
  internal func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(context))
    hasher.combine(name)
    hasher.combine(startLocation)
    hasher.combine(endLocation)
  }
  
}

internal class RewriteContext: Equatable {
  
  internal let url: URL
  
  @inline(__always)
  private var processor: Processor? {
    if let processor = _processor_ {
      return processor
    }
    let processor = Processor(context: self, url: url)
    _processor_ = processor
    return processor
  }
  
  @inlinable
  internal init(url: URL) {
    self.url = url
  }
  
  @inlinable
  internal var isRewritable: Bool {
    get async {
      return await !rewritableDecls.isEmpty
    }
  }
  
  @inlinable
  internal var rewritableDecls: [RewritableDecl] {
    get async {
      guard let rewriter = processor else {
        return []
      }
      return await rewriter.rewritableDecls
    }
  }
  
  @inlinable
  internal func rewrite(_ decls: [RewritableDecl]) async -> String {
    guard let rewriter = processor else {
      return ""
    }
    return await rewriter.rewrite(RewriteRequest(context: self, decls: decls))
  }
  
  // MARK: Equatable
  
  internal static func == (lhs: RewriteContext, rhs: RewriteContext) -> Bool {
    if lhs === rhs {
      return true
    }
    return lhs.url == rhs.url
  }
  
  // MARK: Backwarded Properties
  
  private var _processor_: Processor??
  
}

private struct RewriteRequest: Equatable {
  
  unowned let context: RewriteContext
  
  let decls: [RewritableDecl]
  
  @inline(__always)
  static func == (lhs: RewriteRequest, rhs: RewriteRequest) -> Bool {
    return lhs.context === rhs.context &&
    lhs.decls == rhs.decls
  }
  
}

private class Processor {
  
  private unowned let context: RewriteContext
  
  private let sourceFileSyntax: SourceFileSyntax
  
  private var last: (RewriteRequest, String)?
  
  @inline(__always)
  init?(context: RewriteContext, url: URL) {
    do {
      self.context = context
      self.sourceFileSyntax = try SyntaxParser.parse(url)
    } catch _ {
      return nil
    }
  }
  
  @inline(__always)
  var rewritableDecls: [RewritableDecl] {
    get async {
      if let rewritableDecls = _rewritableDecls_ {
        return rewritableDecls
      }
      let detector = RewritableDeclDetector()
      let decls = await detector.process(
        file: context.url.path,
        tree: sourceFileSyntax,
        context: context
      )
      _rewritableDecls_ = decls
      return decls
    }
  }
  
  @inline(__always)
  func rewrite(_ request: RewriteRequest) async -> String {
    if let (lastRequest, lastResult) = last {
      if lastRequest == request {
        return lastResult
      }
    }
    let rewritableDecls = await rewritableDecls
    let validRequestedDecls = request.decls
      .filter({rewritableDecls.contains($0)})
    let rewriter = DeclRewriter(decls: validRequestedDecls)
    let syntax = await rewriter.process(sourceFileSyntax, context: context)
    return syntax.description
  }
  
  private var _rewritableDecls_: [RewritableDecl]?
  
}

private class RewritableDeclDetector {
  
  init() {
    
  }
  
  func process(
    file: String,
    tree: SourceFileSyntax,
    context: RewriteContext
  ) async -> [RewritableDecl] {
    let converter = SourceLocationConverter(file: file, tree: tree)
    let visitor = Visitor(
      context: context,
      sourceLocationConverter: converter
    )
    visitor.walk(tree)
    return visitor.decls
  }
  
  private class Visitor: SyntaxVisitor {
    
    unowned let context: RewriteContext
    
    let sourceLocationConverter: SourceLocationConverter
    
    var decls: [RewritableDecl]
    
    init(
      context: RewriteContext,
      sourceLocationConverter: SourceLocationConverter
    ) {
      self.context = context
      self.sourceLocationConverter = sourceLocationConverter
      self.decls = []
      super.init()
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
      let startLocation = node.startLocation(converter: sourceLocationConverter)
      let endLocation = node.endLocation(converter: sourceLocationConverter)
      let decl = RewritableDecl(
        context: context,
        name: node.identifier.text,
        startLocation: startLocation,
        endLocation: endLocation
      )
      decls.append(decl)
      return super.visit(node)
    }
    
  }
  
}

private class DeclRewriter {
  
  let decls: [RewritableDecl]
  
  init(decls: [RewritableDecl]) {
    self.decls = decls
  }
  
  func process(
    _ sourceFileSyntax: SourceFileSyntax,
    context: RewriteContext
  ) async -> SourceFileSyntax {
    let visitor = Visitor(sourceFileSyntax: sourceFileSyntax, decls: decls)
    visitor.rewrite()
    return visitor.sourceFileSyntax
  }
  
  private class Visitor: SyntaxVisitor {
    
    var sourceFileSyntax: SourceFileSyntax
    
    let decls: [RewritableDecl]
    
    func rewrite() {
      walk(sourceFileSyntax)
    }
    
    init(sourceFileSyntax: SourceFileSyntax, decls: [RewritableDecl]) {
      self.sourceFileSyntax = sourceFileSyntax
      self.decls = decls
      super.init()
    }
    
  }
  
}
