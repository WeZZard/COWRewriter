//
//  RefactorRequestConfig.swift
//  COWRewriter
//
//  Created by WeZZard on 6/5/22.
//

import Foundation

struct RefactorRequestConfig: Identifiable {
  
  struct UninferrablePatternBindingItem: Identifiable {
    
    let id: UInt
    
    let letOrVar: String
    
    let name: String
    
    let suggestedType: String?
    
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
    RefactorRequest(
      decl: decl,
      storageClassName: userStorageClassName.isEmpty ? suggestedStorageClassName : userStorageClassName,
      storageVariableName: userStorageVariableName.isEmpty ? suggestedStorageVariableName : userStorageVariableName,
      makeUniqueStorageFunctionName: userMakeUniqueStorageFunctionName.isEmpty ? suggestedMakeUniqueStorageFunctionName : userMakeUniqueStorageFunctionName,
      typedefs: Dictionary(uniqueKeysWithValues: uninferrablePatternBindings.map({($0.id, $0.userType.isEmpty ? ($0.suggestedType ?? "") : $0.userType)}))
    )
  }

}
