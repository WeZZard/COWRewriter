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
  var url: URL?
  
  @State
  private var isTargetedDrop: Bool = true
  
  var body: some View {
    HStack(spacing: 16) {
      HStack {
        if let path = url?.path {
          Text(path)
        } else {
          Text("No file open")
            .foregroundColor(.gray)
        }
        Spacer()
      }
      Button("Open", action: onTapSelectFile)
    }
  }
  
  private func onTapSelectFile() {
    if let url = Self.open() {
      self.url = url
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
  
  // MARK: Drag & Drop Support
  
  // TODO: Reuse data in memory when dropping the same url?
  static func onDrop(
    url: Binding<URL?>,
    errorMessage: Binding<String?>
  ) -> ([NSItemProvider]) -> Bool {
    { (providers: [NSItemProvider]) -> Bool in
      Task {
        do {
          let loadedItem = try await providers.first?.loadItem(
            forTypeIdentifier: UTType.fileURL.identifier
          )
          
          guard let data = loadedItem as? Data,
                let path = String(data: data, encoding: .utf8),
                let droppedUrl = URL(string: path) else {
            errorMessage.wrappedValue = "Invalid dropped contents."
            return
          }
          
          let urlType = try? droppedUrl
            .resourceValues(forKeys: [.typeIdentifierKey])
            .typeIdentifier
          
          guard urlType == UTType.swiftSource.identifier else {
            errorMessage.wrappedValue = "\(droppedUrl.path) is not a Swift source file."
            return
          }
          
          url.wrappedValue = droppedUrl
        } catch let error {
          errorMessage.wrappedValue = error.localizedDescription
        }
      }
      
      return true
    }
  }
  
}


struct FilePicker_Previews: PreviewProvider {
  
  static var previews: some View {
    FilePicker(url: .constant(nil))
  }
}
