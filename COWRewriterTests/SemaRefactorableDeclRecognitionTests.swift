//
//  SemaRefactorableDeclRecognitionTests.swift
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

class SemaRefactorableDeclRecognitionTests: SemaTests {
  
  // MARK: Won't Recognize
  
  func testWontRecognizeEmptyStruct() {
    let source = """
    struct Foo {
    
    }
    """
    withSource(source)
      .evaluate(.refactorableDecls)
  }
  
  func testWontRecognizeStructWithoutStoredProperties() {
    let source = """
    struct Foo {
    
      var bar: Bool { return false }
    
    }
    """
    withSource(source)
      .evaluate(.refactorableDecls)
  }
  
  // MARK: Recognizes
  
  func testRecognizesStructWithStoredProperties() {
    let source = """
    struct Foo {
    
      var value: Int = 0
    
    }
    """
    withSource(source)
      .expectRefactorableDecl("Foo")
      .evaluate(.refactorableDecls)
  }
  
  func testRecognizesNestedStructWithStoredProperties() {
    let source = """
    struct Foo {
    
      var value: Int = 0
      
      struct Bar {
      
        var value: Int = 0
      
      }
    }
    """
    withSource(source)
      .expectRefactorableDecl("Foo")
      .expectRefactorableDecl("Bar")
      .evaluate(.refactorableDecls)
  }
  
}
