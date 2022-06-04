//
//  Stdlib+COWRewriterAdditions.swift
//  COWRewriter
//
//  Created by WeZZard on 6/4/22.
//

extension Sequence {
  
  @inlinable
  func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
    return sorted { a, b in
      return a[keyPath: keyPath] < b[keyPath: keyPath]
    }
  }
  
}
