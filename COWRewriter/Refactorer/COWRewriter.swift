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

protocol COWRewriterDelegate: AnyObject {
  
  func rewriter(
    _ sender: COWRewriter,
    shouldRewriteDeclFrom startLocation: SourceLocation,
    to endLocation: SourceLocation
  ) -> Bool
  
}

class COWRewriter {
  
  unowned let input: COWRewriterInputContext
  
  weak var delegate: COWRewriterDelegate?
  
  init(input: COWRewriterInputContext) {
    self.input = input
  }
  
  func execute(request: [RefactorRequest]) -> Syntax {
    let concrete = COWRewriterConcrete(delegate: self, slc: input.slc)
    return concrete.visit(input.tree)
  }
  
}

extension COWRewriter: COWRewriterConcreteDelegate {
  
  fileprivate func rewriter(
    _ sender: COWRewriterConcrete,
    shouldRewriteDeclFrom startLocation: SourceLocation,
    to endLocation: SourceLocation
  ) -> Bool {
    return delegate?.rewriter(
      self,
      shouldRewriteDeclFrom: startLocation,
      to: endLocation
    ) ?? true
  }
  
}

private protocol COWRewriterConcreteDelegate: AnyObject {
  
  func rewriter(
    _ sender: COWRewriterConcrete,
    shouldRewriteDeclFrom startLocation: SourceLocation,
    to endLocation: SourceLocation
  ) -> Bool
  
}


/**
 --- Create Storage Class ------------------------------------------------------
 - Collect struct nested types -> resolve final name for the `Storage` class.
 - Collect struct stored properties.
  - `Storage`'s memberwise initializer shall take default value into consideration.
 -------------------------------------------------------------------------------
 1. Create a storage class, say `Storage`.
 2. Copy all the stored property of the `struct` to `Storage`.
 3. Create the memberwrise initializer for `Storage`.
 4. Create a copy initializer for `Storage`.
 --- Rewrite Struct Decl -------------------------------------------------------
 - Collect struct members
  -> resolve final name for the `storage` variable.
  -> resolve final name for the `makeUniquelyReferencedStorage` function.
  -> resolve if it is necessary to create the memberwise initializer
  -> resolve how many initializers here are needed to be copied to `Storage`
 -------------------------------------------------------------------------------
 5. Create a storage stored property in `struct`, say `storage`.
 6. Create a storage unique-ify function, say `makeUniquelyReferencedStorage`, in `struct`.
 7. Rewrite all the stored properties in `struct` (except the `storage`) with dispatch call to relative properties in `storage`
 8. Copy all the initializers in `struct` to `Storage` (except the memberwise initializer)
 9. Create the memberwrise initializer for `struct` if needed.
 10. Rewrite all the initializers in `struct` with dispatch call to relative initializers in `Storage`
 */

private class COWRewriterConcrete: SyntaxRewriter {
  
  unowned let delegate: COWRewriterConcreteDelegate
  
  let slc: SourceLocationConverter
  
  init(delegate: COWRewriterConcreteDelegate, slc: SourceLocationConverter) {
    self.delegate = delegate
    self.slc = slc
  }
  
  func shouldRewriteDecl(
    from startLocation: SourceLocation,
    to endLocation: SourceLocation
  ) -> Bool {
    delegate.rewriter(
      self,
      shouldRewriteDeclFrom: startLocation,
      to: endLocation
    )
  }
  
}
