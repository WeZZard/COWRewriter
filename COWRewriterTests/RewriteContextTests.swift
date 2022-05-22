//
//  RewriteContextTests.swift
//  COWRewriterTests
//
//  Created by WeZZard on 5/22/22.
//

import XCTest

@testable
import COWRewriter

class RewriteContextTests: XCTestCase {
  
  internal func evaluate(source: String, expected: String, file: StaticString = #file, line: UInt = #line) async {
    let context = RewriteContext(contents: source)
    let actual = await context.rewrite(context.rewritableDecls)
    XCTAssertStringsEqualWithDiff(actual, expected, file: file, line: line)
  }
  
}
