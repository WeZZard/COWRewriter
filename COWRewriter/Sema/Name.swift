//
//  Name.swift
//  COWRewriter
//
//  Created by WeZZard on 6/3/22.
//

import SwiftSyntax

class Name: TextOutputStreamable, CustomStringConvertible, Equatable, Hashable {
  
  enum Kind: CustomStringConvertible {
    
    case type
    
    case function
    
    case variable
    
    case enumCase
    
    case `extension`
    
    var description: String {
      switch self {
      case .type:       return "type"
      case .function:   return "function"
      case .variable:   return "variable"
      case .enumCase:   return "enum-case"
      case .extension:  return "extension"
      }
    }
    
  }
  
  struct Parameter: Hashable {
    
    enum Constraint: Hashable {
      
      case noConstraint
      
      case be(Name)
      
      case beOf([Name])
      
    }
    
    let name: Name
    
    let constraint: Constraint
    
  }
  
  unowned let scope: Scope
  
  let syntaxID: SyntaxIdentifier
  
  let identifier: ScoppedIdentifier?
  
  let kind: Kind
  
  let sourceRange: SourceRange
  
  private(set) var subScopes: [SubScope]
  
  init(
    scope: Scope,
    syntaxID: SyntaxIdentifier,
    identifier: ScoppedIdentifier,
    kind: Kind,
    sourceRange: SourceRange
  ) {
    self.syntaxID = syntaxID
    self.identifier = identifier
    self.scope = scope
    self.kind = kind
    self.sourceRange = sourceRange
    self.subScopes = []
  }
  
  func addSubScope(_ scope: SubScope) {
    subScopes.append(scope)
  }
  
  var scopeContentsDescription: String {
    var description = String()
    write(to: &description)
    return description
  }
  
  func write<Target: TextOutputStream>(to target: inout Target) {
    _recursiveWrite(to: &target, level: 0, indent: 2)
  }
  
  func _recursiveWrite<Target: TextOutputStream>(to target: inout Target, level: Int, indent: Int) {
    let identUnit = String(repeating: " ", count: indent)
    let nameIndent = String(repeating: identUnit, count: level)
    
    // Write the name
    target.write("\(nameIndent)\(identifier.nameEntryDescription) : \(kind)")
    target.write("\n")
    
    // Write the sub scopes
    _recursiveWriteSubscopes(to: &target, level: level + 1, indent: indent)
  }
  
  private func _recursiveWriteSubscopes<Target: TextOutputStream>(
    to target: inout Target,
    level: Int,
    indent: Int
  ) {
    let identUnit = String(repeating: " ", count: indent)
    let subScopeIndent = String(repeating: identUnit, count: level)
    for eachSubScope in subScopes {
      target.write("\(subScopeIndent)-\n")
      eachSubScope._recursiveWrite(to: &target, level: level + 1, indent: indent)
    }
  }
  
  var description: String {
    let id = identifier.nameEntryDescription
    return "<\(Self.self) : \(Unmanaged.passUnretained(self).toOpaque()); identifier = \(id); kind = \(kind)>"
  }
  
  func access(_ members: MemberAccessPath) -> Name? {
    guard members.count > 0 else {
      return nil
    }
    guard self.kind == .type || self.kind == .extension else {
      return nil
    }
    for each in subScopes {
      if let name = each.access(members) {
        return name
      }
    }
    return nil
  }
  
  static func == (lhs: Name, rhs: Name) -> Bool {
    return lhs === rhs
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  
}
