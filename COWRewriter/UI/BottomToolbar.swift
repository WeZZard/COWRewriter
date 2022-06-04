//
//  BottomToolbar.swift
//  COWRewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI

protocol BottomToolbarActions: AnyObject {
  
  func selectAll()
  
  func deselectAll()
  
  func copy() async
  
  func saveAs(url: URL) async throws
  
}

struct BottomToolbar: View {
  
  actor Flags: ObservableObject {
    
    @MainActor
    var isSaving: Bool = false
    
    @MainActor
    var isCopying: Bool = false
    
  }
  
  let actions: BottomToolbarActions
  
  @Binding
  var candidates: [RefactorCandidate]
  
  @Binding
  var refactorRequests: [RefactorRequest]
  
  @StateObject
  private var flags: Flags = Flags()
  
  var body: some View {
    HStack {
      Button("Select All", action: selectAll)
        .disabled(hasSelectedAll || candidates.isEmpty)
      Button("Deselect All", action: deselectAll)
        .disabled(!hasSelectedAll || candidates.isEmpty)
      Spacer()
      Button("Copy ...", action: copy)
        .disabled(refactorRequests.isEmpty && !flags.isCopying)
      Button("Save As ...", action: saveAs)
        .disabled(refactorRequests.isEmpty && !flags.isSaving)
    }
  }
  
  private var hasSelectedAll: Bool {
    candidates.reduce(true, {$0 && $1.isSelected})
  }
  
  private func selectAll() {
    actions.selectAll()
  }
  
  private func deselectAll() {
    actions.deselectAll()
  }
  
  private func copy() {
    guard !flags.isCopying else {
      return
    }
    flags.isCopying = true
    
    Task {
      await actions.copy()
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
    
    guard let url = getURL() else {
      return
    }
    
    flags.isSaving = true
    Task {
      try await actions.saveAs(url: url)
      flags.isSaving = false
    }
  }
  
}
