//
//  ScopeTestsBase.swift
//  COWRewriterTests
//
//  Created by WeZZard on 6/3/22.
//

import XCTest
import SwiftSyntax
import SwiftSyntaxParser
import SwiftSyntaxBuilder

@testable
import COWRewriter

class ScopeTestsBase: XCTestCase {
  
  func withScope<R>(
    of source: String,
    file: StaticString = #file,
    line: UInt = #line,
    do closure: (_ topLevel: TopLevelScope) throws -> R
  ) rethrows -> R {
    do {
      let tree = try SyntaxParser.parse(source: source)
      let builder = ScopeBuilder(file: "IN_MEMORY_SOURCE", tree: tree)
      let scope = try builder.buildScope()
      return try closure(scope)
    } catch let error {
      XCTFail(error.localizedDescription, file: file, line: line)
      abort()
    }
  }
  
  func XCTAssertScopeContents(
    of source: String,
    expected expectedDescription: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    withScope(of: source) { topLevel in
      var actualScope = String()
      topLevel.write(to: &actualScope)
      XCTAssertStringsEqualWithDiff(
        actualScope,
        expectedDescription,
        file: file,
        line: line
      )
    }
  }
  
}
