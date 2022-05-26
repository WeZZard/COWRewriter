//
//  COWRewriter.swift
//  COWRewriter
//
//  Created by WeZZard on 5/26/22.
//

import SwiftSyntax

protocol COWRewriterInputContext: AnyObject {
  
  var file: String? { get }
  
  var tree: Syntax { get }
  
  var slc: SourceLocationConverter { get }
  
}

class COWRewriter {
  
  unowned let input: COWRewriterInputContext
  
  init(input: COWRewriterInputContext) {
    self.input = input
  }
  
  func execute(request: RefactorRequest) -> Syntax {
    let impl = Impl(slc: input.slc)
    return impl.visit(input.tree)
  }
  
  private class Impl: SyntaxRewriter {
    
    let slc: SourceLocationConverter
    
    init(slc: SourceLocationConverter) {
      self.slc = slc
    }
    
  }
}

