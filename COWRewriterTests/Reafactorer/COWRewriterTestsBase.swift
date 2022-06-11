//
//  COWRewriterTestsBase.swift
//  COWRewriterTests
//
//  Created by WeZZard on 5/22/22.
//

import XCTest
import SwiftSyntax
import SwiftSyntaxParser

@testable
import COWRewriter

class COWRewriterTestsBase: XCTestCase {
  
  internal func evaluate(source: String, expected: String, file: StaticString = #file, line: UInt = #line) async {
    
    class Context: COWRewriterInputContext, SemaInputting, SemaOutputting {
      
      let file: String?
      
      var treeID: UInt
      
      var tree: SourceFileSyntax
      
      let slc: SourceLocationConverter
      
      var refactorableDecls: [RefactorableDecl]
      
      @inline(__always)
      init(tree: SourceFileSyntax) {
        self.file = nil
        self.treeID = UInt.random(in: .min...(.max))
        self.tree = tree
        self.slc = SourceLocationConverter(file: "IN_MEMORY_SOURCE", tree: tree)
        self.refactorableDecls = []
      }
      
    }
    
    do {
      let tree = try SyntaxParser.parse(source: source)
      
      let context = Context(tree: tree)
      let sema = Sema(target: .host, input: context, output: context)
      let rewriter = COWRewriter(input: context)
      
      
      sema.performIfNeeded()
      
      let requests = context.refactorableDecls.map {
        RefactorRequest(
          decl: $0,
          storageClassName: $0.namingSuggestions[.storageClassName] ?? "Storage",
          storageVariableName: $0.namingSuggestions[.storageVariableName] ?? "storage",
          storageUniquificationFunctionName: $0.namingSuggestions[.storageUniquificationFunctionName] ?? "makeUniqueStorageIfNeeded",
          typedefs: [:]
        )
      }
      let output = rewriter.execute(requests: requests)
      
      let printer = Printer()
      printer.configs.indentationMode = .space
      printer.configs.indentWidth = 2
      
      let actual = printer.print(syntax: output, url: URL(fileURLWithPath: ""))
      
      XCTAssertStringsEqualWithDiff(actual, expected, file: file, line: line)
    } catch let error {
      XCTFail(error.localizedDescription, file: file, line: line)
    }
    
  }
  
}
