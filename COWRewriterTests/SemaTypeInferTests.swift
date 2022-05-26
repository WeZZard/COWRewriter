//
//  SemaTypeInferTests.swift
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

// TODO: Need to take malformed but parsable AST into consideration?

class SemaTypeInferTests: SemaTests {
  
  // MARK: Can Infer Type of Pattern Binding Syntax
  
  func testPatternBindingWithIntegerLiteral() {
    let source = """
    let value1 = 0
    var value2 = 0
    """
    withSource(source)
      .expect(identifier: "value1", type: "Int")
      .expect(identifier: "value2", type: "Int")
      .evaluate()
  }
  
  func testPatternBindingWithBooleanLiteral() {
    let source = """
    let value1 = true
    let value2 = false
    """
    withSource(source)
      .expect(identifier: "value1", type: "Bool")
      .expect(identifier: "value2", type: "Bool")
      .evaluate()
  }
  
  func testPatternBindingWithFloatingPointLiteral() {
    let source = """
    let value1 = 0.1
    let value2 = 0.2
    """
    withSource(source)
      .expect(identifier: "value1", type: "Double")
      .expect(identifier: "value2", type: "Double")
      .evaluate()
  }
  
  func testPatternBindingWithStringLiteral() {
    let source = """
    let value1 = "a"
    let value2 = "b"
    """
    withSource(source)
      .expect(identifier: "value1", type: "String")
      .expect(identifier: "value2", type: "String")
      .evaluate()
  }
  
  /**
   Three kind of cases:
   
   Initializers whose return type is eventually not clear
   Initializers whose return type is eventually an opaque result type
   Initializers whose return type is eventually a non-opaque result type
   
   And an initializer may be:
   
   - A free function
   - A instance member function
   - A static member function
   - A free variable getter
   - A instance variable getter
   - A static variable getter
   - A instance member closure
   - A static member closure
   - A type initializer
   - An untyped variable
   - An untyped static variable
   
   static/non-static decides scope
   
   init/func/var/closure decides type recognition pattern
   
   */
  
  func testSemaCanRecognizeTypeFromPatternInitializerOfClearResultType() {
    let source = """
    // Free function
    func foo() -> Foo {
      Foo()
    }
    
    // Free variable getter
    var fee: Foo {
      Foo()
    }
    
    struct Foo {
    
      // Type initializer
      Foo() {}
    
      // Static member function
      static func make() -> Foo { Foo() }
    
      // Instance member function
      func bar() -> Foo {
        self
      }
    
      // Instance member variable
      var fee: Foo {
        Foo()
      }
    
      // Static member variable
      static var fee: Foo {
        Foo()
      }
    
      // Instance member closure
      let foe = {
        Foo()
      }
    
      // Instance member closure
      static let foe = {
        Foo()
      }
    
    }
    
    let value1 = foo() // Foo
    let value2 = fee // Foo
    let value3 = Foo() // Foo
    let value4 = Foo.make() // Foo
    let value5 = Foo().bar() // Foo
    let value6 = Foo().fee // Foo
    let value7 = Foo.fee // Foo
    let value8 = Foo().foe() // Foo
    let value9 = Foo.foe() // Foo
    """
    
    withSource(source)
      .expect(identifier: "value1", type: "Foo")
      .expect(identifier: "value2", type: "Foo")
      .expect(identifier: "value3", type: "Foo")
      .expect(identifier: "value4", type: "Foo")
      .expect(identifier: "value5", type: "Foo")
      .expect(identifier: "value6", type: "Foo")
      .expect(identifier: "value7", type: "Foo")
      .expect(identifier: "value8", type: "Foo")
      .expect(identifier: "value9", type: "Foo")
      .ignore(identifier: "fee")
      .ignore(identifier: "Foo.foe")
      .ignore(identifier: "static Foo.foe")
      .evaluate()
  }
  
  func testSemaCanRecognizeTypeFromPatternInitializerOfOpaqueResultType() {
    let source = """
    let value1 = foo()
    
    func foo() -> some Foo {
    }
    """
    
    withSource(source)
      .expect(identifier: "value1", type: "some Foo")
      .evaluate()
  }
  
  func testSemaCanNotRecognizeTypeFromPatternInitializerMissingInSyntaxTree() {
    let source = """
    let value1 = foo()
    """
    
    withSource(source)
      .expect(identifier: "value1", type: nil)
      .evaluate()
  }
  
  // MARK: Type Annotations in Memberwise Initializer Can Contribute to Type Inferring
  
}
