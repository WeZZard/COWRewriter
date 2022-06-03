//
//  ScopeBuilderTests.swift
//  COWRewriterTests
//
//  Created by WeZZard on 5/31/22.
//

import XCTest
import SwiftSyntax
import SwiftSyntaxParser
import SwiftSyntaxBuilder

@testable
import COWRewriter

class ScopeBuilderTests: ScopeTestsBase {
  
  // MARK: Entities in Top Level Code Block
  
  func testTopLevelStoredVariables() {
    let source = """
    var value1 = 0
    """
    let expectedScopeContents = """
    - value1 : variable
    
    """
    XCTAssertScopeContents(of: source, expected: expectedScopeContents)
  }
  
  func testTopLevelComputedVariable() {
    let source = """
    var value1: Int {
      get {
        let value1 = 0
        return value1
      }
      set {
        let value1 = 0
      }
    }
    """
    let expectedScopeContents = """
    - value1 : variable
      -
        - value1 : variable
      -
        - value1 : variable
    
    """
    XCTAssertScopeContents(of: source, expected: expectedScopeContents)
  }
  
  func testTopLevelStruct() {
    let source = """
    struct Foo {
      var value1 = 0
    }
    """
    let expectedScopeContents = """
    - Foo : type
      -
        - value1 : variable
    
    """
    XCTAssertScopeContents(of: source, expected: expectedScopeContents)
  }
  
  func testTopLevelClass() {
    let source = """
    class Foo {
      var value1 = 0
    }
    """
    let expectedScope = """
    - Foo : type
      -
        - value1 : variable
    
    """
    XCTAssertScopeContents(of: source, expected: expectedScope)
  }
  
  func testTopLevelEnum() {
    let source = """
    enum Foo {
      
      case case1
      case case2
      
      var value1: Int {
        let value1 = 0
        return value1
      }
    }
    """
    let expectedScopeContents = """
    - Foo : type
      -
        + case1 : enum-case
        + case2 : enum-case
        - value1 : variable
          -
            - value1 : variable
    
    """
    XCTAssertScopeContents(of: source, expected: expectedScopeContents)
  }
  
  func testTopLevelExtension() {
    let source = """
    struct Foo {
      var value1 = 0
    }
    extension Foo {
      var value2: Int { 0 }
    }
    """
    let expectedScopeContents = """
    - Foo : type
      -
        - value1 : variable
      -
        - value2 : variable
    
    """
    XCTAssertScopeContents(of: source, expected: expectedScopeContents)
  }
  
  // MARK: Entities in Type Member List
  
  func testStructMembers() {
    let source = """
    struct Foo {
      var value1 = 0
      struct Bar {
        var value1 = 0
      }
    }
    """
    let expectedScopeContents = """
    - Foo : type
      -
        - value1 : variable
        - Bar : type
          -
            - value1 : variable
    
    """
    XCTAssertScopeContents(of: source, expected: expectedScopeContents)
  }
  
  func testEnumMembers() {
    let source = """
    enum Foo {
      case case1
      struct Bar {
        var value1 = 0
      }
    }
    """
    let expectedScopeContents = """
    - Foo : type
      -
        + case1 : enum-case
        - Bar : type
          -
            - value1 : variable
    
    """
    XCTAssertScopeContents(of: source, expected: expectedScopeContents)
  }
  
  // MARK: Entities in Name's Code Block List
}
