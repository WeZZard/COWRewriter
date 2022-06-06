//
//  RefactorRequestConfig.swift
//  COWRewriter
//
//  Created by WeZZard on 6/5/22.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxParser

struct RefactorRequestConfig: Identifiable {
  
  struct UninferrablePatternBindingItem: Identifiable {
    
    let id: UInt
    
    let letOrVar: String
    
    let name: String
    
    let suggestedType: TypeSyntax?
    
    var userType: String
    
    init(_ binding: UninferrablePatternBinding) {
      self.id = binding.id
      self.letOrVar = binding.letOrVar
      self.name = binding.identifier
      self.suggestedType = binding.maybeType
      self.userType = ""
    }
    
  }
  
  let id: UUID
  
  let decl: RefactorableDecl
  
  let declName: String
  
  let suggestedStorageClassName: String
  
  var userStorageClassName: String
  
  let suggestedMakeUniqueStorageFunctionName: String
  
  let suggestedStorageVariableName: String
  
  var userStorageVariableName: String
  
  var userMakeUniqueStorageFunctionName: String
  
  var uninferrablePatternBindings: [UninferrablePatternBindingItem]
  
  init(candidate: RefactorCandidate) {
    id = candidate.id
    decl = candidate.content
    declName = candidate.content.identifier
    suggestedStorageClassName = candidate.content.suggestedStorageClassName
    userStorageClassName = ""
    suggestedStorageVariableName = candidate.content.suggestedStorageVariableName
    userStorageVariableName = ""
    suggestedMakeUniqueStorageFunctionName = candidate.content.suggestedMakeUniqueStorageFunctionName
    userMakeUniqueStorageFunctionName = ""
    uninferrablePatternBindings = candidate.content.uninferrablePatternBindings.compactMap(UninferrablePatternBindingItem.init)
  }
  
  var request: RefactorRequest {
    func makeTypeSyntax(_ userType: String?) -> TypeSyntax? {
      guard let userType = userType else {
        return nil
      }
      guard let tree = try? SyntaxParser.parse(source: userType) else {
        return nil
      }
      return tree.statements.first?.item.as(TypeSyntax.self)
    }
    func makeTypedef(_ binding: UninferrablePatternBindingItem) -> (String, TypeSyntax)? {
      guard let type = makeTypeSyntax(binding.userType) ?? binding.suggestedType else {
        return nil
      }
      return (binding.name, type)
    }
    return RefactorRequest(
      decl: decl,
      storageClassName: userStorageClassName.isEmpty ? suggestedStorageClassName : userStorageClassName,
      storageVariableName: userStorageVariableName.isEmpty ? suggestedStorageVariableName : userStorageVariableName,
      makeUniqueStorageFunctionName: userMakeUniqueStorageFunctionName.isEmpty ? suggestedMakeUniqueStorageFunctionName : userMakeUniqueStorageFunctionName,
      typedefs: Dictionary(uniqueKeysWithValues: uninferrablePatternBindings.compactMap(makeTypedef))
    )
  }

}
