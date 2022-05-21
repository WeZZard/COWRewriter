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
  var selectedDecls: Set<Decl>
  
  let rewriteContext: RewriteContext?
  
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
        .disabled(selectedDecls.isEmpty && !flags.isCopying)
      Button("Save As ...", action: saveAs)
        .disabled(selectedDecls.isEmpty && !flags.isSaving)
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
    guard let rewriteContext = rewriteContext,
          !flags.isCopying else {
      return
    }
    flags.isCopying = true
    Task {
      let contents = await rewriteContext.rewrite(selectedDecls.map({$0.rewritableDecl}))
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(contents, forType: .string)
      
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
    
    guard let rewriteContext = rewriteContext,
          !flags.isSaving,
          let url = getURL() else {
      return
    }
    
    flags.isSaving = true
    
    Task {
      let contents = await rewriteContext.rewrite(selectedDecls.map({$0.rewritableDecl}))
      try contents.data(using: .utf8)?.write(to: url)
      flags.isSaving = false
    }
  }
  
  struct Flags {
    
    var isSaving: Bool = false
    
    var isCopying: Bool = false
    
  }
  
}
