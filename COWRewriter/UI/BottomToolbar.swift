//
//  BottomToolbar.swift
//  COWRewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI

struct BottomToolbar: View {
  
  @Binding
  var decls: [Decl]
  
  @Binding
  var refactorRequests: [RefactorRequest]
  
  let refactorer: Refactorer?
  
  let printer: PrettyPrinter
  
  @State
  private var flags: Flags = Flags()
  
  var body: some View {
    HStack {
      Button("Select All", action: selectAll)
        .disabled(hasSelectedAll || decls.isEmpty)
      Button("Deselect All", action: deselectAll)
        .disabled(!hasSelectedAll || decls.isEmpty)
      Spacer()
      Button("Copy ...", action: copy)
        .disabled(refactorRequests.isEmpty && !flags.isCopying)
      Button("Save As ...", action: saveAs)
        .disabled(refactorRequests.isEmpty && !flags.isSaving)
    }
  }
  
  private var hasSelectedAll: Bool {
    decls.reduce(true, {$0 && $1.isSelected})
  }
  
  private func selectAll() {
    for index in decls.indices {
      decls[index].isSelected = true
    }
  }
  
  private func deselectAll() {
    for index in decls.indices {
      decls[index].isSelected = false
    }
  }
  
  private func copy() {
    guard let refactorer = refactorer,
          !flags.isCopying else {
      return
    }
    flags.isCopying = true
    Task {
      let contents = await refactorer.refactor(refactorRequests)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(printer.print(contents), forType: .string)
      flags.isCopying = false
    }
  }
  
  private func saveAs() {
    func getURL() -> URL? {
      let savePanel = NSSavePanel()
      savePanel.allowedContentTypes = [.swiftSource]
      savePanel.canCreateDirectories = true
      savePanel.isExtensionHidden = false
      savePanel.allowsOtherFileTypes = false
      let response = savePanel.runModal()
      return response == .OK ? savePanel.url : nil
    }
    
    guard let refactorer = refactorer,
          !flags.isSaving,
          let url = getURL() else {
      return
    }
    
    flags.isSaving = true
    
    Task {
      let syntax = await refactorer.refactor(refactorRequests)
      let text = printer.print(syntax)
      try text.data(using: .utf8)?.write(to: url)
      flags.isSaving = false
    }
  }
  
  struct Flags {
    
    var isSaving: Bool = false
    
    var isCopying: Bool = false
    
  }
  
}
