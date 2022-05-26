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
import SwiftSyntaxBuilder

private protocol Context: AnyObject {
  
  var contextID: ObjectIdentifier { get }
  
  var sourceLocationConverter: SourceLocationConverter { get }
  
}

private class StructInfo {
  
  unowned let context: Context
  
  let decl: StructDeclSyntax
  
  var subtypes: [StructInfo]
  
  var identifier: String {
    decl.identifier.text
  }
  
  var startLocation: SourceLocation {
    decl.startLocation(converter: context.sourceLocationConverter)
  }
  
  var endLocation: SourceLocation {
    decl.endLocation(converter: context.sourceLocationConverter)
  }
  
  var storedPropertyMembers: [VariableDeclSyntax] {
    if let decls = _storedPropertyMembers_ {
      return decls
    }
    let decls = decl.members.members.compactMap(\.decl.asStoredPropertyDecl)
    _storedPropertyMembers_ = decls
    return decls
  }
  
  var resolvedStorageClassName: String {
    fatalError()
  }
  
  @inline(__always)
  init(context: Context, decl: StructDeclSyntax) {
    self.context = context
    self.decl = decl
    self.subtypes = []
  }
  
  private var _storedPropertyMembers_: [VariableDeclSyntax]?
  
}

private var typeInfos: [StructInfo] = []

fileprivate func createStorageClass(_ structInfo: StructInfo) -> ClassDeclSyntax {
  func createMemberwiseInitializer() -> InitializerDeclSyntax {
    InitializerDeclSyntax { initializer in
      initializer.useInitKeyword(.`init`)
      initializer.useParameters(ParameterClauseSyntax { parameters in
        parameters.addParameter(FunctionParameterSyntax { funcParam in
          
        })
      })
      initializer.useBody(CodeBlockSyntax { codeBlock in
        for each in structInfo.storedPropertyMembers {
          let item = CodeBlockItemSyntax { item in
            
          }
        }
      })
    }
  }
  
  func createCopyInitializer() -> InitializerDeclSyntax {
    InitializerDeclSyntax { initializer in
      
    }
  }
  
  return ClassDeclSyntax { builder in
    builder.useClassOrActorKeyword(.class)
    builder.useIdentifier(.identifier(structInfo.resolvedStorageClassName))
    builder.useMembers(MemberDeclBlockSyntax { memberDeclBlock in
      // Copy stored properties in struct
      for eachItem in structInfo.storedPropertyMembers {
        memberDeclBlock.addMember(MemberDeclListItemSyntax { item in
          item.useDecl(DeclSyntax(eachItem))
        })
      }
      // Create memberwise initializer
      memberDeclBlock.addMember(MemberDeclListItemSyntax { item in
        item.useDecl(DeclSyntax(createMemberwiseInitializer()))
      })
      // Create copy initializer
      memberDeclBlock.addMember(MemberDeclListItemSyntax { item in
        item.useDecl(DeclSyntax(createCopyInitializer()))
      })
    })
  }
}

/**
 --- Create Storage Class ------------------------------------------------------
 - Collect struct nested types -> resolve final name for the `Storage` class.
 - Collect struct stored properties.
  - `Storage`'s memberwise initializer shall take default value into consideration.
 -------------------------------------------------------------------------------
 1. Create a storage class, say `Storage`.
 2. Copy all the stored property of the `struct` to `Storage`.
 3. Create the memberwrise initializer for `Storage`.
 4. Create a copy initializer for `Storage`.
 --- Rewrite Struct Decl -------------------------------------------------------
 - Collect struct members
  -> resolve final name for the `storage` variable.
  -> resolve final name for the `makeUniquelyReferencedStorage` function.
  -> resolve if it is necessary to create the memberwise initializer
  -> resolve how many initializers here are needed to be copied to `Storage`
 -------------------------------------------------------------------------------
 5. Create a storage stored property in `struct`, say `storage`.
 6. Create a storage unique-ify function, say `makeUniquelyReferencedStorage`, in `struct`.
 7. Rewrite all the stored properties in `struct` (except the `storage`) with dispatch call to relative properties in `storage`
 8. Copy all the initializers in `struct` to `Storage` (except the memberwise initializer)
 9. Create the memberwrise initializer for `struct` if needed.
 10. Rewrite all the initializers in `struct` with dispatch call to relative initializers in `Storage`
 */

internal struct RewritableDecl: Equatable, Hashable {
  
  fileprivate let contextID: ObjectIdentifier
  
  internal let name: String
  
  internal let startLocation: SourceLocation
  
  internal let endLocation: SourceLocation
  
  @inline(__always)
  internal static func == (lhs: RewritableDecl, rhs: RewritableDecl) -> Bool {
    return lhs.contextID == rhs.contextID &&
    lhs.name == rhs.name &&
    lhs.startLocation == rhs.startLocation &&
    lhs.endLocation == rhs.endLocation
  }
  
  internal func hash(into hasher: inout Hasher) {
    hasher.combine(contextID)
    hasher.combine(name)
    hasher.combine(startLocation)
    hasher.combine(endLocation)
  }
  
}

internal class RewriteContext: Equatable {
  
  private let url: URL?
  
  private var contents: String {
    get async {
      if let content = _contents_ {
        return content
      }
      let string: String
      if let url = url {
        string = (try? String(contentsOfFile: url.path, encoding: .utf8)) ?? ""
      } else {
        string = ""
      }
      _contents_ = string
      return string
    }
  }
  
  @inline(__always)
  private var processor: Processor? {
    get async {
      if let processor = _processor_ {
        return processor
      }
      let processor = Processor(
        contextID: ObjectIdentifier(self),
        source: await contents,
        url: url
      )
      _processor_ = processor
      return processor
    }
  }
  
  @inlinable
  internal convenience init(url: URL) {
    self.init(url: url, contents: nil)
  }
  
  @inlinable
  internal convenience init(contents: String) {
    self.init(url: nil, contents: contents)
  }
  
  @inline(__always)
  private init(url: URL?, contents: String?) {
    self.url = url
    self._contents_ = contents
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
      guard let rewriter = await processor else {
        return []
      }
      return await rewriter.rewritableDecls
    }
  }
  
  @inlinable
  internal func rewrite(_ decls: [RewritableDecl]) async -> String {
    guard let rewriter = await processor else {
      return ""
    }
    return await rewriter.rewrite(RewriteRequest(context: self, decls: decls))
  }
  
  // MARK: Equatable
  
  @inlinable
  internal static func == (lhs: RewriteContext, rhs: RewriteContext) -> Bool {
    return lhs === rhs
  }
  
  // MARK: Backwarded Properties
  
  private var _contents_: String?
  
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
  
  private let contextID: ObjectIdentifier
  
  private let url: URL?
  
  private let sourceFileSyntax: SourceFileSyntax
  
  private var last: (RewriteRequest, String)?
  
  @inline(__always)
  init?(contextID: ObjectIdentifier, source: String, url: URL?) {
    do {
      self.url = url
      self.contextID = contextID
      self.sourceFileSyntax = try SyntaxParser.parse(source: source)
    } catch _ {
      return nil
    }
  }
  
  @inline(__always)
  private var file: String {
    url?.path ?? ""
  }
  
  @inline(__always)
  var rewritableDecls: [RewritableDecl] {
    get async {
      if let rewritableDecls = _rewritableDecls_ {
        return rewritableDecls
      }
      let detector = RewritableDeclDetector()
      let decls = await detector.process(
        file: file,
        tree: sourceFileSyntax,
        contextID: contextID
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
    let syntax = await rewriter.process(
      file: file,
      tree: sourceFileSyntax,
      contextID: contextID
    )
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
    contextID: ObjectIdentifier
  ) async -> [RewritableDecl] {
    let slc = SourceLocationConverter(file: file, tree: tree)
    let visitor = Visitor(contextID: contextID, slc: slc)
    visitor.walk(tree)
    return visitor.decls
  }
  
  private class Visitor: SyntaxVisitor {
    
    let contextID: ObjectIdentifier
    
    let slc: SourceLocationConverter
    
    var decls: [RewritableDecl]
    
    init(contextID: ObjectIdentifier, slc: SourceLocationConverter) {
      self.contextID = contextID
      self.slc = slc
      self.decls = []
      super.init()
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
      let startLocation = node.startLocation(converter: slc)
      let endLocation = node.endLocation(converter: slc)
      let decl = RewritableDecl(
        contextID: contextID,
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
    file: String,
    tree: SourceFileSyntax,
    contextID: ObjectIdentifier
  ) async -> SourceFileSyntax {
    let slc = SourceLocationConverter(file: file, tree: tree)
    let visitor = Visitor(sourceFileSyntax: tree, slc: slc, decls: decls)
    visitor.rewrite()
    return visitor.result ?? visitor.sourceFileSyntax
  }
  
  private class Visitor: SyntaxRewriter {
    
    var sourceFileSyntax: SourceFileSyntax
    
    let slc: SourceLocationConverter
    
    let decls: [RewritableDecl]
    
    private(set) var result: SourceFileSyntax?
    
    func rewrite() {
      result = SourceFileSyntax(visit(sourceFileSyntax))
    }
    
    init(
      sourceFileSyntax: SourceFileSyntax,
      slc: SourceLocationConverter,
      decls: [RewritableDecl]
    ) {
      self.sourceFileSyntax = sourceFileSyntax
      self.slc = slc
      self.decls = decls
      self.result = sourceFileSyntax
      super.init()
    }
    
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
      let result = super.visit(node)
      
      guard canRewrite(node) else {
        return result
      }
      
      return rewrite(node)
    }
    
    private func rewrite(_ ndoe: StructDeclSyntax) -> DeclSyntax {
      fatalError()
    }
    
    private func canRewrite(_ node: StructDeclSyntax) -> Bool {
      // The struct be specified in `decls` array.
      guard decls.contains(where: {
        $0.startLocation == node.startLocation(converter: slc) &&
        $0.endLocation == node.endLocation(converter: slc)
      }) else {
        return false
      }
      
      guard node.storedProertiesCount > 0 else {
        return false
      }
      
      guard !node.hasAppliedCopyOnWriteTechniques else {
        return false
      }
      
      return true
    }
    
  }
  
}

extension StructDeclSyntax {
  
  @inline(__always)
  fileprivate var storedProertiesCount: Int {
    members.members.filter { item in
      if let varDecl = item.decl.as(VariableDeclSyntax.self) {
        return varDecl.isStored
      }
      return false
    }.count
  }
  
  @inline(__always)
  fileprivate var hasAppliedCopyOnWriteTechniques: Bool {
    // 1. Only one class stored property
    guard storedProertiesCount == 1 else {
      return false
    }
    
    let allVarDeclMembers = members.members.compactMap({$0.decl.as(VariableDeclSyntax.self)})
    
    guard let uniqueStored = allVarDeclMembers.first else {
      return false
    }
    
    let type = uniqueStored.bindings.first!.typeAnnotation
    
    // 2. call to isKnownUniquelyReferenced
    
    fatalError()
  }
  
}

extension VariableDeclSyntax {
  
  fileprivate var isStored: Bool {
    if letOrVarKeyword.tokenKind == .letKeyword {
      return true
    }
    guard bindings.count == 1 else {
      return false
    }
    guard let first = bindings.first else {
      return false
    }
    return first.accessor == nil && first.initializer != nil
  }
  
}


extension DeclSyntax {
  
  @inline(__always)
  fileprivate var isStoredPropertyDecl: Bool {
    return asStoredPropertyDecl != nil
  }
  
  @inline(__always)
  fileprivate var asStoredPropertyDecl: VariableDeclSyntax? {
    guard let decl = self.as(VariableDeclSyntax.self), decl.isStored else {
      return nil
    }
    return decl
  }
  
}

