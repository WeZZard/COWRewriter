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
      
      var tree: Syntax
      
      let slc: SourceLocationConverter
      
      var refactorableDecls: [RefactorableDecl]
      
      @inline(__always)
      init(tree: SourceFileSyntax) {
        self.file = nil
        self.treeID = UInt.random(in: .min...(.max))
        self.tree = Syntax(tree)
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
      
      let request = RefactorRequest(
        decls: context.refactorableDecls,
        typedefs: [:]
      )
      let output = rewriter.execute(request: request)
      
      let actual = output.description
      
      XCTAssertStringsEqualWithDiff(actual, expected, file: file, line: line)
    } catch let error {
      XCTFail(error.localizedDescription, file: file, line: line)
    }
    
  }
  
}
