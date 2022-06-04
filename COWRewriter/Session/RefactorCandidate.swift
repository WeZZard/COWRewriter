//
//  RefactorCandidate.swift
//  COWRewriter
//
//  Created by WeZZard on 6/5/22.
//

import Foundation

struct RefactorCandidate: Hashable, Identifiable {
  
  let content: RefactorableDecl
  
  let id: UUID
  
  var isSelected: Bool
  
  init(content: RefactorableDecl) {
    self.content = content
    self.id = UUID()
    self.isSelected = false
  }
  
}
