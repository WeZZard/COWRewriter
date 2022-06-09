//
//  Binding+COWRewriterAdditions.swift
//  COWRewriter
//
//  Created by WeZZard on 6/9/22.
//

import SwiftUI

extension Binding {
  
  func animated(_ animated: Bool) -> Binding<Value> {
    if animated {
      return animation()
    }
    return self
  }
  
}
