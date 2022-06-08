//
//  PrinterConfigs.swift
//  COWRewriter
//
//  Created by WeZZard on 6/8/22.
//

struct PrinterConfigs: Equatable {
  
  enum IndentationMode: Hashable, CaseIterable {
    
    case tab
    
    case space
    
    var displayName: String {
      switch self {
      case .tab:    return "Tabs"
      case .space:  return "Spaces"
      }
    }
    
  }
  
  var indentationMode: IndentationMode
  
  var tabWidth: Int
  
  var indentWidth: Int
  
  init() {
    indentationMode = .tab
    tabWidth = 2
    indentWidth = 2
  }
  
}
