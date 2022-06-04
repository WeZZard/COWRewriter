//
//  FilePicker.swift
//  COWRewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum FileDropError: Error {
  
  case systemError(Error)
  
  case invalidDropData
  
  case notSwiftSource(url: URL)
  
}

struct FilePicker: View {
  
  @Binding
  var selectedFileURL: URL?
  
  @State
  private var isTargetedDrop: Bool = true
  
  @State
  private var importErrorMessage: String? = nil
  
  var body: some View {
    VStack {
      HStack(spacing: 16) {
        HStack {
          if let path = selectedFileURL?.path {
            Text(path)
          } else {
            Text("No file open")
              .foregroundColor(.gray)
          }
          Spacer()
        }
        Button(
          selectedFileURL == nil ? "Open" : "Open Another",
          action: onTapSelectFile
        )
      }
      ImportErrorMessageView(
        importErrorMessage: animatedImportErrorMessage,
        fadeEdge: .top
      )
    }
    .onDrop(
      of: [.fileURL],
      isTargeted: nil,
      perform: FilePicker.onDrop(
        url: animatedSelectedFileURL,
        errorMessage: animatedImportErrorMessage
      )
    )
  }
  
  private func onTapSelectFile() {
    if let url = Self.open() {
      self.selectedFileURL = url
    }
  }
  
  static func open() -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.swiftSource]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK else {
      return nil
    }
    return panel.url
  }
  
  private var animatedImportErrorMessage: Binding<String?> {
    $importErrorMessage.animation(.easeInOut)
  }
  
  private var animatedSelectedFileURL: Binding<URL?> {
    $selectedFileURL.animation(.easeInOut)
  }
  
  // MARK: Drag & Drop Support
  
  // TODO: Reuse data in memory when dropping the same url?
  static func onDrop(
    url: Binding<URL?>,
    errorMessage: Binding<String?>
  ) -> ([NSItemProvider]) -> Bool {
    
    @Sendable
    @MainActor
    func updateUrl(_ droppedUrl: URL) {
      url.wrappedValue = droppedUrl
    }
    
    @Sendable
    @MainActor
    func updateErrorMessage(_ string: String) {
      errorMessage.wrappedValue = string
    }
    
    return { (providers: [NSItemProvider]) -> Bool in
      Task {
        do {
          let loadedItem = try await providers.first?.loadItem(
            forTypeIdentifier: UTType.fileURL.identifier
          )
          
          guard let data = loadedItem as? Data,
                let path = String(data: data, encoding: .utf8),
                let droppedUrl = URL(string: path) else {
            await updateErrorMessage("Invalid dropped contents.")
            return
          }
          
          let urlType = try? droppedUrl
            .resourceValues(forKeys: [.typeIdentifierKey])
            .typeIdentifier
          
          guard urlType == UTType.swiftSource.identifier else {
            await updateErrorMessage("\(droppedUrl.path) is not a Swift source file.")
            return
          }
          
          await updateUrl(droppedUrl)
        } catch let error {
          await updateErrorMessage(error.localizedDescription)
        }
      }
      
      return true
    }
  }
  
}


struct FilePicker_Previews: PreviewProvider {
  
  static var previews: some View {
    FilePicker(selectedFileURL: .constant(nil))
  }
}
