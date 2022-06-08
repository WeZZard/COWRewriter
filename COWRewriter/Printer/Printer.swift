//
//  Printer.swift
//  COWRewriter
//
//  Created by WeZZard on 6/4/22.
//

import Foundation
import SwiftSyntax
import SwiftFormat
import SwiftFormatCore
import SwiftFormatConfiguration
import SwiftFormatPrettyPrint

class Printer {
  
  var configs: PrinterConfigs
  
  init(configs: PrinterConfigs = PrinterConfigs()) {
    self.configs = configs
  }
  
  func print(syntax: SourceFileSyntax, url: URL) -> String {
    var configuration = Configuration()
    configuration.tabWidth = configs.tabWidth
    switch configs.indentationMode {
    case .space:
      configuration.indentation = .spaces(configs.indentWidth)
    case .tab:
      configuration.indentation = .tabs(configs.indentWidth)
    }
    
    let context = Context(
      configuration: configuration,
      findingConsumer: nil,
      fileURL: url,
      sourceFileSyntax: syntax,
      source: nil,
      ruleNameCache: [:]
    )
    
    let operatorContext = OperatorContext.makeBuiltinOperatorContext()
    let printer = PrettyPrinter(
      context: context,
      operatorContext: operatorContext,
      node: Syntax(syntax),
      printTokenStream: false,
      whitespaceOnly: false)
    return printer.prettyPrint()
  }
  
}
