//
//  ScopeNameLookUpTests.swift
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

class ScopeNameLookUpTests: ScopeTestsBase {
  
  func testLookUpReturnsName() {
    let source = """
    let value1 = 0
    let value2 = 0
    """
    withScope(of: source) { topLevel in
      let value1 = topLevel.lookup(.make(name: "value1"))
      let value2 = topLevel.lookup(.make(name: "value2"))
      XCTAssertNotNil(value1)
      XCTAssertNotNil(value2)
      XCTAssertNotEqual(value1, value2)
    }
  }
  
}

