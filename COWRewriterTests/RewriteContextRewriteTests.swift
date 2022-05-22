//
//  RewriteContextRewriteTests.swift
//  COWRewriterTests
//
//  Created by WeZZard on 5/22/22.
//

import XCTest

class RewriteContextRewriteTests: RewriteContextTests {
  
  func testRewriteContextRewritesStructWithSingleStoredProperty() async {
    let source = """
    struct Foo {
      var foo: Int
        
      init(foo: Int) {
        self.foo = foo
      }
    
    }
    """
    
    let expected = """
    struct Foo {
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
            
      private var storage: Storage
      
      init(foo: Int) {
        self.storage = Storage(foo: foo)
      }
      
      var foo: Int {
        _read {
          yield storage.foo
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.foo
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
  
  func testRewriteContextRewritesStructWithAllStoredProperties() async {
    let source = """
    struct Foo {
      var fee: Int
      
      var foe: Int
      
      var fum: Int
      
      init(fee: Int, foe: Int, fum: Int) {
        self.fee = fee
        self.foe = foe
        self.fum = fum
      }
    }
    """
    
    let expected = """
    struct Foo {
      var fee: Int {
        _read {
          yield storage.fee
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.fee
        }
      }
      
      var foe: Int {
        _read {
          yield storage.foe
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.foe
        }
      }
      
      var fum: Int {
        _read {
          yield storage.fum
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.fum
        }
      }
      
      private var storage: Storage
      
      init(fee: Int, foe: Int, fum: Int) {
        self.storage = Storage(fee: fee, foe: foe, fum: fum)
      }
      
      private class Storage {
        var fee: Int
        
        var foe: Int
        
        var fum: Int
        
        @inline(__always)
        init(fee: Int, foe: Int, fum: Int) {
          self.fee = fee
          self.foe = foe
          self.fum = fum
        }
        
        @inline(__always)
        convenience init(_ storage: Storage) {
          self.init(fee: storage.fee, foe: storage.foe, fum: storage.fum)
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
  
  func testRewriteContextRewritesStructWithStoredPropertiesAndLeftComputedPropertiesAlone() async {
    let source = """
    struct Foo {
      var fee: Int
      
      var foe: Int
      
      var fum: Int
    
      var bar: Int { 0 }
      
      init(fee: Int, foe: Int, fum: Int) {
        self.fee = fee
        self.foe = foe
        self.fum = fum
      }
    }
    """
    
    let expected = """
    struct Foo {
      var fee: Int {
        _read {
          yield storage.fee
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.fee
        }
      }
      
      var foe: Int {
        _read {
          yield storage.foe
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.foe
        }
      }
      
      var fum: Int {
        _read {
          yield storage.fum
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.fum
        }
      }
      
      var bar: Int { 0 }
      
      private var storage: Storage
      
      init(fee: Int, foe: Int, fum: Int) {
        self.storage = Storage(fee: fee, foe: foe, fum: fum)
      }
      
      private class Storage {
        var fee: Int
        
        var foe: Int
        
        var fum: Int
        
        @inline(__always)
        init(fee: Int, foe: Int, fum: Int) {
          self.fee = fee
          self.foe = foe
          self.fum = fum
        }
        
        @inline(__always)
        convenience init(_ storage: Storage) {
          self.init(fee: storage.fee, foe: storage.foe, fum: storage.fum)
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
  
  func testRewriteContextRewritesStructWithUniqueStoredPropertyAndExsitedNestedStorageClass() async {
    let source = """
    struct Foo {
      var fee: Int
      
      var foe: Int
      
      var fum: Int
    
      class Storage {
      }
      
      init(fee: Int, foe: Int, fum: Int) {
        self.fee = fee
        self.foe = foe
        self.fum = fum
      }
    }
    """
    
    let expected = """
    struct Foo {
      var fee: Int {
        _read {
          yield storage.fee
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.fee
        }
      }
      
      var foe: Int {
        _read {
          yield storage.foe
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.foe
        }
      }
      
      var fum: Int {
        _read {
          yield storage.fum
        }
        _modify {
          makeUniquelyReferencedStorage()
          yield &storage.fum
        }
      }
      
      private var storage: Storage2
          
      class Storage {
      }
            
      init(fee: Int, foe: Int, fum: Int) {
        self.storage = Storage2(fee: fee, foe: foe, fum: fum)
      }
      
      private class Storage2 {
        var fee: Int
        
        var foe: Int
        
        var fum: Int
        
        @inline(__always)
        init(fee: Int, foe: Int, fum: Int) {
          self.fee = fee
          self.foe = foe
          self.fum = fum
        }
        
        @inline(__always)
        convenience init(_ storage: Storage2) {
          self.init(fee: storage.fee, foe: storage.foe, fum: storage.fum)
        }
      }
      
      @inline(__always)
      private mutating func makeUniquelyReferencedStorage() {
        guard !isKnownUniquelyReferenced(&storage) else {
          return
        }
        storage = Storage2(storage)
      }
      
    }
    """
    
    await evaluate(source: source, expected: expected)
  }
  
}
