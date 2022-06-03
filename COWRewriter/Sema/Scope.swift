//
//  Scope.swift
//  COWRewriter
//
//  Created by WeZZard on 5/29/22.
//

import SwiftSyntax
import SwiftUI
import OSLog

// TODO: Support type parameterization

struct ScoppedIdentifier: Hashable {
  
  /// Indicates whether this identifier is of static or class.
  let isStatic: Bool
  
  let name: String
  
  var nameEntryDescription: String {
    "\(isStatic ? "+" : "-") \(name)"
  }
  
}

extension Optional where Wrapped == ScoppedIdentifier {
  
  var nameEntryDescription: String {
    map(\.nameEntryDescription) ?? "- (anonymous)"
  }
  
}


struct ScopeOptions {
  
  enum Kind {
    
    case codeBlockItemList
    
    case memberList
    
  }
  
  static let topLevel = ScopeOptions(
    isTopLevel: true,
    allowsStatic: false,
    kind: .codeBlockItemList
  )
  
  static let type = ScopeOptions(
    isTopLevel: false,
    allowsStatic: true,
    kind: .memberList
  )
  
  static let body = ScopeOptions(
    isTopLevel: false,
    allowsStatic: false,
    kind: .codeBlockItemList
  )
  
  let isTopLevel: Bool
  
  let allowsStatic: Bool
  
  let kind: Kind
  
  init(isTopLevel: Bool, allowsStatic: Bool, kind: Kind) {
    self.isTopLevel = isTopLevel
    self.allowsStatic = allowsStatic
    self.kind = kind
  }
  
  init(_ nameKind: Name.Kind) {
    switch nameKind {
    case .variable:   self = .body
    case .function:   self = .body
    case .extension:  self = .type
    case .type:       self = .type
    case .enumCase:   preconditionFailure()
    }
  }
  
}

class Scope: TextOutputStreamable, CustomStringConvertible {
  
  let options: ScopeOptions
  
  private(set) var names: [Name]
  
  init(options: ScopeOptions) {
    self.options = options
    self.names = []
  }
  
  func addName(_ name: Name) {
    names.append(name)
  }
  
  var scopeContentsDescription: String {
    var description = String()
    write(to: &description)
    return description
  }
  
  func write<Target: TextOutputStream>(to target: inout Target) {
    _recursiveWrite(to: &target, level: 0, indent: 2)
  }
  
  func _recursiveWrite<Target: TextOutputStream>(
    to target: inout Target,
    level: Int,
    indent: Int
  ) {
    for eachName in names {
      eachName._recursiveWrite(to: &target, level: level, indent: indent)
    }
  }
  
  var description: String {
    return "<\(Self.self) : \(Unmanaged.passUnretained(self).toOpaque())>"
  }
  
  /// Lookup upwards.
  func lookup(_ lookup: NameLookUpRequest) -> Name? {
    if options.kind == .memberList {
      for each in names {
        if each.identifier?.name == lookup.name {
          return each.access(lookup.members)
        }
      }
    }
    return nil
  }
  
  // func declare
  
  // func use
  
}


class TopLevelScope: Scope, CustomDebugStringConvertible {
  
  static func make(file: String, tree: SourceFileSyntax) throws -> TopLevelScope {
    let builder = ScopeBuilder(file: file, tree: tree)
    return try builder.buildScope()
  }
  
  fileprivate(set) var allNames: [SyntaxIdentifier : Name]
  
  init() {
    self.allNames = [:]
    super.init(options: .topLevel)
  }
  
  override func addName(_ name: Name) {
    super.addName(name)
    allNames[name.syntaxID] = name
  }
  
  override func lookup(_ lookup: NameLookUpRequest) -> Name? {
    for each in names {
      if each.identifier?.name == lookup.name {
        return each
      }
    }
    return nil
  }
  
  var debugDescription: String {
    var description = String()
    write(to: &description)
    return description
  }
  
}

class SubScope: Scope {
  
  unowned let parent: Name
  
  init(parent: Name, options: ScopeOptions) {
    self.parent = parent
    super.init(options: options)
  }
  
  var topLevel: TopLevelScope {
    var scopeOrNil: Scope? = parent.scope
    while let scope = scopeOrNil {
      if let topLevel = scope as? TopLevelScope {
        return topLevel
      } else if let subScope = scope as? SubScope {
        scopeOrNil = subScope.parent.scope
      } else {
        preconditionFailure()
      }
    }
    preconditionFailure()
  }
  
  override func addName(_ name: Name) {
    super.addName(name)
    topLevel.allNames[name.syntaxID] = name
  }
  
  override func lookup(_ lookup: NameLookUpRequest) -> Name? {
    if let result = super.lookup(lookup) {
      return result
    }
    return parent.scope.lookup(lookup)
  }
  
  func access(_ members: MemberAccessPath) -> Name? {
    guard members.count > 0 else {
      return nil
    }
    let first = members[0]
    for each in names {
      if each.identifier?.name == first {
        return each.access(members.dequeueingFirst())
      }
    }
    return nil
  }
  
}
