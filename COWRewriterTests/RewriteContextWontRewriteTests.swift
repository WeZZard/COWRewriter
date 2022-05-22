//
//  RewriteContextWontRewriteTests.swift
//  COWRewriterTests
//
//  Created by WeZZard on 5/22/22.
//

import XCTest

class RewriteContextWontRewriteTests: RewriteContextTests {
  
  func testRewriteContextWontRewriteEmptyStruct() async {
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
  
  func testRewriteContextWontRewriteStructWithUniqueComputedProperty() async {
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
  
  func testRewriteContextWontRewriteStructWithDedicatedMultipleComputedProperty() async {
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
  
  func testRewriteContextWontRewriteStructWithUniqueStoredPropertyWhichHashAppliedCOWTechniques() async {
    let source = """
    struct Foo {
      var foo: Int {
        _read {
          yield storage.foo
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.foo
        }
      }
      
      init(foo: Int) {
        self.storage = Storage(foo: foo)
      }
      
      private var storage: Storage
    
      private class Storage {
        var foo: Int
        
        @inline(__always)
        init(foo: Int) {
          self.foo = foo
        }
    
        @inline(__always)
        convenience init(storage: Storage) {
          self.init(foo: storage.foo)
        }
      }
      
      @inline(__always)
      private mutating func makeUniquelyReferencedStorage() {
        guard !isKnownUniquelyReferenced(&storage) else {
          return
        }
        storage = Storage(storage)
      }
    }
    """
    
    let expected = """
    struct Foo {
      var foo: Int {
        _read {
          yield storage.foo
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.foo
        }
      }
      
      init(foo: Int) {
        self.storage = Storage(foo: foo)
      }
      
      private var storage: Storage
    
      private class Storage {
        var foo: Int
        
        @inline(__always)
        init(foo: Int) {
          self.foo = foo
        }
    
        @inline(__always)
        convenience init(_ storage: Storage) {
          self.init(foo: storage.foo)
        }
      }
      
      @inline(__always)
      private mutating func makeUniquelyReferencedStorage() {
        guard !isKnownUniquelyReferenced(&storage) else {
          return
        }
        storage = Storage(storage)
      }
    }
    """
    
    await evaluate(source: source, expected: expected)
  }
  
  func testRewriteContextWontRewriteStructWithUniqueStoredPropertyWhichHashAppliedCOWTechniquesWithArbitraryStorageClass() async {
    let source = """
    struct Foo {
      var foo: Int {
        _read {
          yield bar.foo
        }
        _modify {
          makeUnique()
          yield &bar.foo
        }
      }
      
      init(foo: Int) {
        self.bar = Bar(foo: foo)
      }
      
      private var bar: Bar
    
      private class Bar {
        var foo: Int
        
        @inline(__always)
        init(foo: Int) {
          self.foo = foo
        }
    
        @inline(__always)
        convenience init(_ bar: Bar) {
          self.init(foo: bar.foo)
        }
      }
      
      @inline(__always)
      private mutating func makeUnique() {
        guard !isKnownUniquelyReferenced(&bar) else {
          return
        }
        bar = Bar(bar)
      }
    }
    """
    
    let expected = """
    struct Foo {
      var foo: Int {
        _read {
          yield bar.foo
        }
        _modify {
          makeUnique()
          yield &bar.foo
        }
      }
      
      init(foo: Int) {
        self.bar = Bar(foo: foo)
      }
      
      private var bar: Bar
    
      private class Bar {
        var foo: Int
        
        @inline(__always)
        init(foo: Int) {
          self.foo = foo
        }
    
        @inline(__always)
        convenience init(_ bar: Bar) {
          self.init(foo: bar.foo)
        }
      }
      
      @inline(__always)
      private mutating func makeUnique() {
        guard !isKnownUniquelyReferenced(&bar) else {
          return
        }
        bar = Bar(bar)
      }
    }
    """
    
    await evaluate(source: source, expected: expected)
  }
  
}
