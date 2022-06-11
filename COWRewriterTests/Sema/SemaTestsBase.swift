//
//  SemaTestsBase.swift
//  COWRewriterTests
//
//  Created by WeZZard on 5/26/22.
//

import XCTest
import SwiftSyntax
import SwiftSyntaxParser
import SwiftSyntaxBuilder

@testable
import COWRewriter

class SemaTestsBase: XCTestCase {
  
  class EvaluationRequestBuilder {
    
    private struct TypeCheckResult {
      let type: String?
      let file: StaticString
      let line: UInt
    }
    
    private struct RefactorableDeclDetectionResult {
      let identifier: String
      let file: StaticString
      let line: UInt
    }
    
    let source: String
    
    private var expectedTypeCheckResults: [GlobalIdentifier : TypeCheckResult]
    
    private var ignoredIdentifiers: Set<GlobalIdentifier>
    
    private var expectRefactorableDecls: [RefactorableDeclDetectionResult]
    
    init(source: String) {
      self.source = source
      self.expectedTypeCheckResults = [:]
      self.ignoredIdentifiers = []
      self.expectRefactorableDecls = []
    }
    
    func expectTypeChecking(
      _ identifier: GlobalIdentifier,
      with type: String?,
      file: StaticString = #file,
      line: UInt = #line
    ) -> EvaluationRequestBuilder {
      expectedTypeCheckResults[identifier] = TypeCheckResult(
        type: type,
        file: file,
        line: line
      )
      return self
    }
    
    func ignoreTypeChecking(
      _ identifier: GlobalIdentifier
    ) -> EvaluationRequestBuilder {
      ignoredIdentifiers.insert(identifier)
      return self
    }
    
    func expectRefactorableDecl(
      _ identifier: String,
      file: StaticString = #file,
      line: UInt = #line
    ) -> EvaluationRequestBuilder {
      expectRefactorableDecls.append(
        RefactorableDeclDetectionResult(
          identifier: identifier,
          file: file,
          line: line
        )
      )
      return self
    }
    
    struct EvaluationOptions: OptionSet {
      
      typealias RawValue = UInt8
      
      var rawValue: RawValue
      
      init(rawValue: RawValue) {
        self.rawValue = rawValue
      }
      
      static let typeCheck              = EvaluationOptions(rawValue: 0x1 << 0)
      static let refactorableDecls      = EvaluationOptions(rawValue: 0x1 << 1)
      static let all: EvaluationOptions = [typeCheck, refactorableDecls]
      
    }
    
    func evaluate(
      _ options: EvaluationOptions = .all,
      file: StaticString = #file,
      line: UInt = #line
    ) {
      guard !options.isEmpty else {
        return
      }
      
      do {
        
        let context = try Context(source: source)
        let sema = Sema(target: .of64Bit, input: context, output: context)
        sema.performIfNeeded()
        
        if options.contains(.typeCheck) {
          evaluateTypeCheck(tree: sema.output.tree, file: file, line: line)
        }
        if options.contains(.refactorableDecls) {
          evaluateRefactorableDeclsDetection(actual: sema.output.refactorableDecls, file: file, line: line)
        }
        
      } catch let error {
        XCTFail(error.localizedDescription, file: file, line: line)
      }
    }
    
    private func evaluateTypeCheck(tree: SourceFileSyntax, file: StaticString, line: UInt) {
      let reader = BindingsReader(tree: tree)
      reader.readIfNeeded()
      for (identifier, eachExpectation) in expectedTypeCheckResults {
        if let readType = reader.bindings[identifier] {
          switch (readType, eachExpectation.type) {
          case let (.some(readType), .some(builtType)):
            XCTAssertEqual(
              readType,
              builtType,
              "Type bound to \"\(identifier) : \(readType)\" is different from the expectation: \"\(builtType)\".",
              file: eachExpectation.file,
              line: eachExpectation.line
            )
          case let (.some(readType), .none):
            XCTFail(
              "Type bound to \"\(identifier) : \(readType)\" is different from the expectation: nil.",
              file: eachExpectation.file,
              line: eachExpectation.line
            )
          case let (.none, .some(builtType)):
            XCTFail(
              "No type bound to \"\(identifier)\". Expecting \"\(builtType)\".",
              file: eachExpectation.file,
              line: eachExpectation.line
            )
          case (.none, .none):
            break
          }
        } else {
          XCTFail(
            "\"\(identifier)\" has not read. There may be some issues in \(_typeName(BindingsReader.self)) or you need to check your expectations.",
            file: eachExpectation.file,
            line: eachExpectation.line
          )
        }
      }
      for (identifier, readType) in reader.bindings {
        if !expectedTypeCheckResults.keys.contains(identifier) && !ignoredIdentifiers.contains(identifier) {
          if let readType = readType {
            XCTFail(
              "\"\(identifier) : \(readType)\" has read but not found in expectations. There may be some issues in \(_typeName(BindingsReader.self)) or you need to check your expectations.",
              file: file,
              line: line
            )
          } else {
            XCTFail(
              "\"\(identifier)\" has read but not found in expectations. There may be some issues in \(_typeName(BindingsReader.self)) or you need to check your expectations.",
              file: file,
              line: line
            )
          }
        }
      }
    }
    
    private func evaluateRefactorableDeclsDetection(actual: [RefactorableDecl], file: StaticString, line: UInt) {
      for eachExpected in expectRefactorableDecls {
        if !actual.contains(where: {$0.identifier == eachExpected.identifier}) {
          XCTFail(
            "Expected refactorable decl of identifier \"\(eachExpected.identifier)\" is not detected.",
            file: eachExpected.file,
            line: eachExpected.line
          )
        }
      }
      for eachActual in actual {
        if !expectRefactorableDecls.contains(where: {$0.identifier == eachActual.identifier}) {
          XCTFail(
            "Unexpected refactorable decl of identifier \"\(eachActual.identifier)\" detected.",
            file: file,
            line: line
          )
        }
      }
    }
    
  }
  
  internal func withSource(_ source: String) -> EvaluationRequestBuilder {
    EvaluationRequestBuilder(source: source)
  }
  
  internal typealias Bindings = [GlobalIdentifier : String?]
  
  @resultBuilder
  internal struct BindingsBuilder {
    
    static func buildBlock(_ components: (String, String?)...) -> Bindings {
      Bindings(uniqueKeysWithValues: components)
    }
    
  }
  
  /// A simple, global unique and human readable string for an identifier.
  typealias GlobalIdentifier = String
  
  private class Context: SemaInputting, SemaOutputting {
    
    var tree: SourceFileSyntax
    
    let treeID: UInt
    
    var refactorableDecls: [RefactorableDecl]
    
    let slc: SourceLocationConverter
    
    init(source: String) throws {
      self.tree = try SyntaxParser.parse(source: source)
      self.treeID = UInt.random(in: .min...(.max))
      self.refactorableDecls = []
      self.slc = SourceLocationConverter(file: "IN_MEMORY_SOURCE", source: source)
    }
    
  }
  
  /// - Note:
  /// Currently does not support private.
  ///
  /// Private members have their context id, which is hardly to be derived by
  /// human rememberable rules. This conflict the design that the global
  /// identifier is a simple human readable string.
  ///
  private class BindingsReader: SyntaxVisitor {
    
    class Node {
      
      enum Payload {
        case topLevel(children: [Node])
        indirect case variable(
          parent: Node,
          isStatic: Bool,
          children: [Node]
        )
        indirect case function(
          parent: Node,
          isStatic: Bool,
          signature: String,
          children: [Node]
        )
        indirect case binding(
          parent: Node,
          identifier: String,
          type: String?,
          children: [Node]
        )
        indirect case getter(
          parent: Node,
          children: [Node]
        )
        indirect case setter(
          parent: Node,
          children: [Node]
        )
        indirect case `enum`(
          parent: Node,
          identifier: String,
          children: [Node]
        )
        indirect case `struct`(
          parent: Node,
          identifier: String,
          children: [Node]
        )
        indirect case `class`(
          parent: Node,
          identifier: String,
          children: [Node]
        )
        indirect case `extension`(
          parent: Node,
          extentedType: String,
          whereClause: String?,
          children: [Node]
        )
        indirect case codeBlock(
          parent: Node,
          children: [Node]
        )
        
      }
      
      private(set) var payload: Payload
      
      init(payload: Payload) {
        self.payload = payload
      }
      
      var parent: Node? {
        switch payload {
        case .topLevel:
          return nil
        case .variable(let parent, _, _):
          return parent
        case .function(let parent, _, _, _):
          return parent
        case .binding(let parent, _, _, _):
          return parent
        case .getter(let parent, _):
          return parent
        case .setter(let parent, _):
          return parent
        case .enum(let parent, _, _):
          return parent
        case .struct(let parent, _, _):
          return parent
        case .class(let parent, _, _):
          return parent
        case .extension(let parent, _, _, _):
          return parent
        case .codeBlock(let parent, _):
          return parent
        }
      }
      
      func addChild(_ node: Node) {
        func addChildToChildren(_ children: inout [Node]) {
          children.append(node)
        }
        switch payload {
        case .topLevel(var children):
          addChildToChildren(&children)
          self.payload = .topLevel(children: children)
        case .variable(let parent, let isStatic, var children):
          addChildToChildren(&children)
          self.payload = .variable(parent: parent, isStatic: isStatic, children: children)
        case .function(let parent, let isStatic, let signature, var children):
          addChildToChildren(&children)
          self.payload = .function(parent: parent, isStatic: isStatic, signature: signature, children: children)
        case .binding(let parent, let identifier, let type, var children):
          addChildToChildren(&children)
          self.payload = .binding(parent: parent, identifier: identifier, type: type, children: children)
        case .getter(let parent, var children):
          addChildToChildren(&children)
          self.payload = .getter(parent: parent, children: children)
        case .setter(let parent, var children):
          addChildToChildren(&children)
          self.payload = .setter(parent: parent, children: children)
        case .enum(let parent, let identifier, var children):
          addChildToChildren(&children)
          self.payload = .enum(parent: parent, identifier: identifier, children: children)
        case .struct(let parent, let identifier, var children):
          addChildToChildren(&children)
          self.payload = .struct(parent: parent, identifier: identifier, children: children)
        case .class(let parent, let identifier, var children):
          addChildToChildren(&children)
          self.payload = .class(parent: parent, identifier: identifier, children: children)
        case .extension(let parent, let extentedType, let whereClause, var children):
          addChildToChildren(&children)
          self.payload = .`extension`(parent: parent, extentedType: extentedType, whereClause: whereClause, children: children)
        case .codeBlock(let parent, var children):
          addChildToChildren(&children)
          self.payload = .codeBlock(parent: parent, children: children)
        }
      }
      
      var isVariable: Bool {
        if case .variable = payload {
          return true
        }
        return false
      }
      
      var isBinding: Bool {
        if case .binding = payload {
          return true
        }
        return false
      }
      
      var asBinding: (identifier: String, type: String?) {
        guard case let .binding(_, id, ty, _) = payload else {
          preconditionFailure()
        }
        return (id, ty)
      }
      
      func makeBinding() -> (GlobalIdentifier, String?) {
        precondition(isBinding)
        var all = [self]
        
        var parentOrNil: Node? = self.parent
        while let parent = parentOrNil {
          all.append(parent)
          parentOrNil = parent.parent
        }
        
        let identifier = all.reversed().compactMap(\.componentDescription).joined(separator: ".")
        let type = asBinding.type
        return (identifier, type)
      }
      
      var componentDescription: String? {
        switch payload {
        case .topLevel(_):
          return nil
        case .variable(_, let isStatic, _):
          if isStatic {
            return "static"
          } else {
            return nil
          }
        case .function(_, let isStatic, let signature, _):
          if isStatic {
            return "static.\(signature)"
          } else {
            return signature
          }
        case .binding(_, let identifier, _, _):
          return identifier
        case .getter(_, _):
          return "getter"
        case .setter(_, _):
          return "setter"
        case .enum(_, let identifier, _):
          return identifier
        case .struct(_, let identifier, _):
          return identifier
        case .class(_, let identifier, _):
          return identifier
        case .extension(_, let extentedType, let whereClause, _):
          if let whereClause = whereClause {
            return "(extension)\(extentedType)<\(whereClause)>"
          } else {
            return "(extension)\(extentedType)"
          }
        case .codeBlock(_, _):
          return nil
        }
      }
      
    }
    
    let tree: SourceFileSyntax
    
    private(set) var bindings: Bindings
    
    private var hasRead: Bool
    
    private let rootNode: Node
    
    private unowned var topNode: Node
    
    init(tree: SourceFileSyntax) {
      let node = Node(payload: .topLevel(children: []))
      self.tree = tree
      self.bindings = [:]
      self.hasRead = false
      self.rootNode = node
      self.topNode = node
    }
    
    func readIfNeeded() {
      if !hasRead {
        read()
        hasRead = true
      }
    }
    
    private func read() {
      walk(tree)
    }
    
    private func push(_ payload: Node.Payload) {
      let node = Node(payload: payload)
      topNode.addChild(node)
      topNode = node
    }
    
    private func pop() {
      topNode = topNode.parent!
    }
    
    private func makeBinding() {
      let (key, value) = topNode.makeBinding()
      bindings[key] = value
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
      push(
        .variable(
          parent: topNode,
          isStatic: node.modifiers?.containsStatic == true,
          children: []
        )
      )
      return super.visit(node)
    }
    
    override func visitPost(_ node: VariableDeclSyntax) {
      super.visitPost(node)
      pop()
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
      let signature = node.identifier.simpleDescription +
        node.signature.simpleDescription
      push(
        .function(
          parent: topNode,
          isStatic: node.modifiers?.containsStatic == true,
          signature: signature,
          children: []
        )
      )
      return super.visit(node)
    }
    
    override func visitPost(_ node: FunctionDeclSyntax) {
      super.visitPost(node)
      pop()
    }
    
    override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
      if let idSyntax = node.pattern.as(IdentifierPatternSyntax.self) {
        let typeSyntax = node.typeAnnotation?.type.as(SimpleTypeIdentifierSyntax.self)
        let id = idSyntax.simpleDescription
        let type = typeSyntax?.simpleDescription
        push(.binding(parent: topNode, identifier: id, type: type, children: []))
        makeBinding()
      }
      return super.visit(node)
    }
    
    override func visitPost(_ node: PatternBindingSyntax) {
      super.visitPost(node)
      if node.pattern.is(IdentifierPatternSyntax.self) {
        pop()
      }
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
      push(.struct(parent: topNode, identifier: node.identifier.text, children: []))
      return super.visit(node)
    }
    
    override func visitPost(_ node: StructDeclSyntax) {
      super.visitPost(node)
      pop()
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
      push(.`class`(parent: topNode, identifier: node.identifier.text, children: []))
      return super.visit(node)
    }
    
    override func visitPost(_ node: ClassDeclSyntax) {
      super.visitPost(node)
      pop()
    }
    
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
      push(.`enum`(parent: topNode, identifier: node.identifier.text, children: []))
      return super.visit(node)
    }
    
    override func visitPost(_ node: EnumDeclSyntax) {
      super.visitPost(node)
      pop()
    }
    
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
      push(
        .extension(
          parent: topNode,
          extentedType: node.extendedType.simpleDescription,
          whereClause: node.genericWhereClause?.simpleDescription,
          children: []
        )
      )
      return super.visit(node)
    }
    
    override func visitPost(_ node: ExtensionDeclSyntax) {
      super.visitPost(node)
      pop()
    }
    
    override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
      if topNode.isVariable {
        push(.getter(parent: topNode, children: []))
      } else {
        push(.codeBlock(parent: topNode, children: []))
      }
      return super.visit(node)
    }
    
    override func visitPost(_ node: CodeBlockSyntax) {
      super.visitPost(node)
      pop()
    }
    
  }
}

extension ModifierListSyntax {
  
  fileprivate var containsStatic: Bool {
    self.contains { decl in
      decl.firstToken?.tokenKind == .staticKeyword
    }
  }
  
}

extension SyntaxProtocol {
  
  var simpleDescription: String {
    withoutTrivia().description
  }
  
}
