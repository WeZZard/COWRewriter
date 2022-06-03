//
//  Transaction.swift
//  COWRewriter
//
//  Created by WeZZard on 6/2/22.
//


/// Transaction for building an instance of `Name`.
class Transaction: CustomStringConvertible {
  
  init() {
    
  }
  
  var description: String {
    return "<\(Self.self) : \(Unmanaged.passUnretained(self).toOpaque())>"
  }
  
}

class VariableTransaction: Transaction {
  
  unowned let scope: Scope
  
  let isStatic: Bool
  
  private(set) var names: [Name]
  
  init(scope: Scope, isStatic: Bool) {
    self.scope = scope
    self.isStatic = isStatic
    self.names = []
  }
  
  func appendName(_ name: Name) {
    self.names.append(name)
  }
  
  private func notAllowedError(_ type: Any.Type) -> Never {
    fatalError("Appending \(_typeName(type)) to variable transaction is not allowed!")
  }
  
}

class PatternBindingTransaction: Transaction {
  
  enum Element {
    
    case name(Name)
    
    case subScope(SubScope)
    
    var asName: Name {
      guard case let .name(name) = self else {
        preconditionFailure()
      }
      return name
    }
    
    var asSubScope: SubScope {
      guard case let .subScope(subScope) = self else {
        preconditionFailure()
      }
      return subScope
    }
    
  }
  
  enum Cursor {
    
    case identifier
    
    case getter
    
    case setter
    
    var next: Cursor? {
      switch self {
      case .identifier:
        return .getter
      case .getter:
        return .setter
      case .setter:
        return nil
      }
    }
    
  }
  
  unowned let variable: VariableTransaction
  
  private(set) var cursor: Cursor?
  
  private(set) var identifier: Name?
  
  private(set) var getter: SubScope?
  
  private(set) var setter: SubScope?
  
  init(variable: VariableTransaction) {
    self.variable = variable
    self.cursor = .identifier
  }
  
  func append(_ element: Element) {
    if cursor == .identifier {
      identifier = element.asName
    } else if cursor == .getter {
      getter = element.asSubScope
    } else if cursor == .setter {
      setter = element.asSubScope
    }
    cursor = cursor?.next
  }
  
}
