//
//  COWRewriter.swift
//  COWRewriter
//
//  Created by WeZZard on 5/26/22.
//

import SwiftSyntax
import SwiftSyntaxBuilder

protocol COWRewriterInputContext: AnyObject {
  
  var file: String? { get }
  
  var tree: SourceFileSyntax { get }
  
  var slc: SourceLocationConverter { get }
  
}

enum COWRewriterError: Error {
  
  case noInferredTypeAndUserType(node: StructDeclSyntax, storageName: String)
  
}

class COWRewriter {
  
  unowned let input: COWRewriterInputContext
  
  private(set) var errors: [COWRewriterError]
  
  init(input: COWRewriterInputContext) {
    self.input = input
    self.errors = []
  }
  
  func execute(requests: [RefactorRequest]) -> SourceFileSyntax {
    let concrete = COWRewriterConcrete(slc: input.slc, requests: requests)
    return SourceFileSyntax(concrete.visit(input.tree)) ?? input.tree
  }
  
}

/**
 --- Create Storage Class ------------------------------------------------------
 - Collect struct nested types -> resolve final name for the `Storage` class.
 - Collect struct stored properties.
 - `Storage`'s memberwise initializer shall take default value into consideration.
 -------------------------------------------------------------------------------
 1. Create a storage class, say `Storage`.
 2. Copy all the stored property of the `struct` to `Storage`.
 3. Collect all initializers of the `struct` and copy to `Storage`.
 4. Create the memberwrise initializer for `Storage` if needed.
 5. Create a copy initializer for `Storage`.
 --- Rewrite Struct Decl -------------------------------------------------------
 - Collect struct members
 -> resolve final name for the `storage` variable.
 -> resolve final name for the `makeUniquelyReferencedStorage` function.
 -> resolve if it is necessary to create the memberwise initializer
 -> resolve how many initializers here are needed to be copied to `Storage`
 -------------------------------------------------------------------------------
 6. Create a storage stored property in `struct`, say `storage`.
 7. Create a storage unique-ify function, say `makeUniquelyReferencedStorage`, in `struct`.
 8. Rewrite all the stored properties in `struct` (except the `storage`) with dispatch call to relative properties in `storage`
 9. Create the memberwrise initializer for `struct` if needed.
 10. Rewrite all the initializers in `struct` with dispatch call to relative initializers in `Storage`
 */

private class COWRewriterConcrete: SyntaxRewriter {
  
  let slc: SourceLocationConverter
  
  let requests: [RefactorRequest]
  
  private(set) var errors: [COWRewriterError]
  
  init(slc: SourceLocationConverter, requests: [RefactorRequest]) {
    self.slc = slc
    self.requests = requests
    self.errors = []
  }
  
  override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
    guard let request = requests.firstRequest(for: node.sourceRange(converter: slc)) else {
      return super.visit(node)
    }
    
    let resolvedStorageNameAndTypes = resolveStorageNameAndTypes(
      for: node,
      with: request.typedefs,
      errors: &self.errors
    )
    
    let storageClass = makeStorageClass(
      structDecl: node,
      className: request.storageClassName,
      resolvedStorageNameAndTypes: resolvedStorageNameAndTypes
    )
    
    let refactoredSyntax = makeCowStruct(
      originalStructDecl: node,
      storageClass: storageClass,
      storageVariableName: request.storageVariableName,
      storageUniquificationFunctionName: request.makeUniqueStorageFunctionName,
      resolvedStorageNameAndTypes: resolvedStorageNameAndTypes
    )
    
    return DeclSyntax(refactoredSyntax)
  }
  
}

private func resolveStorageNameAndTypes(
  for structDecl: StructDeclSyntax,
  with userTypeForStorageName: [String : TypeSyntax],
  errors: inout [COWRewriterError]
) -> [String : TypeSyntax] {
  let storedVariables = structDecl.members.members.storedVariables
  let storageNamesAndTypes = Dictionary(
    uniqueKeysWithValues: storedVariables.flatMap(\.allIdentifiersAndTypes)
  )
  
  var resolvedStorageNameAndTypes = [String : TypeSyntax]()
  for (storageName, typeOrNil) in storageNamesAndTypes {
    let userTypeOrNil = userTypeForStorageName[storageName]
    let resolvedTypeOrNil = typeOrNil ?? userTypeOrNil
    guard let resolvedType = resolvedTypeOrNil else {
      errors.append(COWRewriterError.noInferredTypeAndUserType(node: structDecl, storageName: storageName))
      continue
    }
    resolvedStorageNameAndTypes[storageName] = resolvedType
  }
  return resolvedStorageNameAndTypes
}

extension Sequence where Element == RefactorRequest {
  
  func firstRequest(for sourceRange: SourceRange) -> RefactorRequest? {
    for each in self where each.decl.sourceRange == sourceRange {
      return each
    }
    return nil
  }
  
}

extension MemberDeclListSyntax {
  
  var storedVariables: [VariableDeclSyntax] {
    compactMap { member -> VariableDeclSyntax? in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
            variableDecl.isStored else {
        return nil
      }
      return variableDecl
    }
  }
  
  var initializers: [InitializerDeclSyntax] {
    compactMap { member -> InitializerDeclSyntax? in
      guard let initDecl = member.decl.as(InitializerDeclSyntax.self) else {
        return nil
      }
      return initDecl
    }
  }
  
}

extension VariableDeclSyntax {
  
  var isStored: Bool {
    if letOrVarKeyword == .let {
      return true
    }
    return bindings.reduce(true) { (partial, binding) in
      partial && binding.accessor == nil
    }
  }
  
}

extension VariableDeclSyntax {
  
  fileprivate var allIdentifiersAndTypes: [String : TypeSyntax?] {
    let allIdentifiersAndTypes = bindings
      .compactMap { binding -> (String, TypeSyntax?)? in
        guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
          return nil
        }
        
        let type = binding.typeAnnotation?.type
        
        return (identifierPattern.identifier.text, type)
      }
    return Dictionary(uniqueKeysWithValues: allIdentifiersAndTypes)
  }
  
}

