//
//  RefactorRequestConfig.swift
//  COWRewriter
//
//  Created by WeZZard on 6/5/22.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxParser

struct RefactorRequestConfig: Equatable, Identifiable {
  
  let id: UUID
  
  let decl: RefactorableDecl
  
  let declName: String
  
  var unresolvedSemanticsItems: [UnresolvedSemanticsItem]
  
  init(candidate: RefactorCandidate) {
    id = candidate.id
    let content = candidate.content
    decl = content
    declName = content.identifier
    unresolvedSemanticsItems = content.unresolvedSemantics.map(UnresolvedSemanticsItem.init)
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
    func makeTypedef(_ item: UnresolvedSemanticsItem) -> (String, TypeSyntax)? {
      guard case let .typeAnnotation(issue) = item,
            let type = makeTypeSyntax(issue.userType) ?? issue.suggestedType else {
        return nil
      }
      return (issue.name, type)
    }
    func select<Items: Sequence>(
      key: UnresolvedSemantics.NamingIssue.Key,
      from items: Items
    ) -> String? where Items.Element == UnresolvedSemanticsItem {
      for item in items {
        guard case let .name(issue) = item, issue.key == key else {
          continue
        }
        return issue.userSpecifiedName.isEmpty
          ? issue.suggestedName
          : issue.userSpecifiedName
      }
      return nil
    }
    return RefactorRequest(
      decl: decl,
      storageClassName: select(key: .storageClassName, from: unresolvedSemanticsItems) ?? "",
      storageVariableName: select(key: .storageVariableName, from: unresolvedSemanticsItems) ?? "",
      storageUniquificationFunctionName: select(key: .storageUniquificationFunctionName, from: unresolvedSemanticsItems) ?? "",
      typedefs: Dictionary(uniqueKeysWithValues: unresolvedSemanticsItems.compactMap(makeTypedef))
    )
  }
  
  enum UnresolvedSemanticsItem: Equatable, Identifiable {
    
    case name(NamingIssue)
    
    case typeAnnotation(TypeAnnotationIssue)
    
    @inline(__always)
    var id: UInt {
      switch self {
      case let .name(issue):            return issue.id
      case let .typeAnnotation(issue):  return issue.id
      }
    }
    
    init(_ semantics: UnresolvedSemantics) {
      switch semantics {
      case let .name(issue):
        self = .name(NamingIssue(issue))
      case let .typeAnnotation(issue):
        self = .typeAnnotation(TypeAnnotationIssue(issue))
      }
    }
    
    struct TypeAnnotationIssue: Equatable, Identifiable {
      
      let id: UInt
      
      let letOrVar: String
      
      let name: String
      
      let suggestedType: TypeSyntax?
      
      var userType: String
      
      init(_ issue: UnresolvedSemantics.TypeAnnotationIssue) {
        self.id = issue.id
        self.letOrVar = issue.letOrVar
        self.name = issue.identifier
        self.suggestedType = issue.maybeType
        self.userType = ""
      }
      
    }
    
    struct NamingIssue: Equatable {
      
      let id: UInt
      
      let key: Key
      
      let suggestedName: String
      
      var userSpecifiedName: String
      
      init(_ issue: UnresolvedSemantics.NamingIssue) {
        self.id = issue.id
        self.key = issue.key
        self.suggestedName = issue.suggestedName ?? ""
        self.userSpecifiedName = ""
      }
      
      typealias Key = UnresolvedSemantics.NamingIssue.Key
      
    }
  }
  
}
