//
//  FilePicker.swift
//  COWRewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
  
  static func onDrop(url: Binding<URL?>) -> ([NSItemProvider]) -> Bool {
    { (providers: [NSItemProvider]) -> Bool in
      providers.first?.loadDataRepresentation(
        forTypeIdentifier: UTType.fileURL.identifier
      ) { dataOrNil, _ in
        guard let data = dataOrNil,
              let path = String(data: data, encoding: .utf8) else {
          return
        }
        let droppedUrl = URL(string: path)
        let urlType = try? droppedUrl?
          .resourceValues(forKeys: [.typeIdentifierKey])
          .typeIdentifier
        guard urlType == UTType.swiftSource.identifier else {
          return
        }
        url.wrappedValue = droppedUrl
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
