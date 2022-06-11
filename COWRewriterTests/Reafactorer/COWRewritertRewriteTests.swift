//
//  COWRewriterRewriteTests.swift
//  COWRewriterTests
//
//  Created by WeZZard on 5/22/22.
//

import XCTest

class COWRewriterRewriteTests: COWRewriterTestsBase {
  
  func testRewritesStructWithSingleStoredProperty() async {
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
    
        init(foo: Int) {
          self.foo = foo
        }
    
        init(_ storage: Storage) {
          self.foo = storage.foo
        }
      }
    
      private var storage: Storage
    
      private mutating func makeUniqueStorageIfNeeded() {
        guard !isKnownUniquelyReferenced(&storage) else { return }
        self.storage = Storage(storage)
      }
    
      var foo: Int {
        _read { yield self.storage.foo }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.foo
        }
      }
    
      init(foo: Int) {
        self.storage = Storage(foo: foo)
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
      private class Storage {
        var fee: Int
    
        var foe: Int
    
        var fum: Int
    
        init(fee: Int, foe: Int, fum: Int) {
          self.fee = fee
          self.foe = foe
          self.fum = fum
        }
    
        init(_ storage: Storage) {
          self.fee = storage.fee
          self.foe = storage.foe
          self.fum = storage.fum
        }
      }
    
      private var storage: Storage
    
      private mutating func makeUniqueStorageIfNeeded() {
        guard !isKnownUniquelyReferenced(&storage) else { return }
        self.storage = Storage(storage)
      }
    
      var fee: Int {
        _read { yield self.storage.fee }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.fee
        }
      }
    
      var foe: Int {
        _read { yield self.storage.foe }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.foe
        }
      }
    
      var fum: Int {
        _read { yield self.storage.fum }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.fum
        }
      }
    
      init(fee: Int, foe: Int, fum: Int) {
        self.storage = Storage(fee: fee, foe: foe, fum: fum)
      }
    }
    
    """
    
    await evaluate(source: source, expected: expected)
  }
  
  func testRewritesStructWithStoredPropertiesAndLeftComputedPropertiesAlone() async {
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
      private class Storage {
        var fee: Int
    
        var foe: Int
    
        var fum: Int
    
        init(fee: Int, foe: Int, fum: Int) {
          self.fee = fee
          self.foe = foe
          self.fum = fum
        }
    
        init(_ storage: Storage) {
          self.fee = storage.fee
          self.foe = storage.foe
          self.fum = storage.fum
        }
      }
    
      private var storage: Storage
    
      private mutating func makeUniqueStorageIfNeeded() {
        guard !isKnownUniquelyReferenced(&storage) else { return }
        self.storage = Storage(storage)
      }
    
      var fee: Int {
        _read { yield self.storage.fee }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.fee
        }
      }
    
      var foe: Int {
        _read { yield self.storage.foe }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.foe
        }
      }
    
      var fum: Int {
        _read { yield self.storage.fum }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.fum
        }
      }
    
      init(fee: Int, foe: Int, fum: Int) {
        self.storage = Storage(fee: fee, foe: foe, fum: fum)
      }
    
      var bar: Int { 0 }
    }
    
    """
    
    await evaluate(source: source, expected: expected)
  }
  
  func testRewritesStructWithUniqueStoredPropertyAndExsitedNestedStorageClass() async {
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
      private class Storage2 {
        var fee: Int
    
        var foe: Int
    
        var fum: Int
    
        init(fee: Int, foe: Int, fum: Int) {
          self.fee = fee
          self.foe = foe
          self.fum = fum
        }
    
        init(_ storage: Storage2) {
          self.fee = storage.fee
          self.foe = storage.foe
          self.fum = storage.fum
        }
      }
    
      private var storage: Storage2
    
      private mutating func makeUniqueStorageIfNeeded() {
        guard !isKnownUniquelyReferenced(&storage) else { return }
        self.storage = Storage2(storage)
      }
    
      var fee: Int {
        _read { yield self.storage.fee }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.fee
        }
      }
    
      var foe: Int {
        _read { yield self.storage.foe }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.foe
        }
      }
    
      var fum: Int {
        _read { yield self.storage.fum }
        _modify {
          self.makeUniqueStorageIfNeeded()
          yield &self.storage.fum
        }
      }
    
      init(fee: Int, foe: Int, fum: Int) {
        self.storage = Storage2(fee: fee, foe: foe, fum: fum)
      }
    
      class Storage {
      }
    }
    
    """
    
    await evaluate(source: source, expected: expected)
  }
  
}
