//
//  COWRewriterWontRewriteTests.swift
//  COWRewriterTests
//
//  Created by WeZZard on 5/22/22.
//

import XCTest

class COWRewriterWontRewriteTests: COWRewriterTestsBase {
  
  func testWontRewriteEmptyStruct() async {
    let source = """
    struct Foo {
    }
    """
    
    let expected = """
    struct Foo {
    }
    
    """
    
    await evaluate(source: source, expected: expected)
  }
  
  func testWontRewriteStructWithUniqueComputedProperty() async {
    let source = """
    struct Foo {
    
      var value: Int { 0 }
    
    }
    """
    
    let expected = """
    struct Foo {
    
      var value: Int { 0 }
    
    }
    
    """
    
    await evaluate(source: source, expected: expected)
  }
  
  func testWontRewriteStructWithDedicatedMultipleComputedProperty() async {
    let source = """
    struct Foo {
    
      var fee: Int { 0 }
    
      var foe: Int { 0 }
      
      var fum: Int { 0 }
    
    }
    """
    
    let expected = """
    struct Foo {
    
      var fee: Int { 0 }
    
      var foe: Int { 0 }
    
      var fum: Int { 0 }
    
    }
    
    """
    
    await evaluate(source: source, expected: expected)
  }
  
}
