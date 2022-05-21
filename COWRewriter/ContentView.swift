//
//  ContentView.swift
//  COW Rewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI

struct ContentView: View {
  
  @State
  var chosenURL: URL? = nil
  
  @State
  var decls: [Decl] = []
  
  @State
  var fileContent: String = ""
  
  @State
  var selectedDecls: Set<UUID> = []
  
  @State
  var showFileChooser = false
  
  var chosenFilename: String {
    chosenURL?.lastPathComponent ?? "No file chosen."
  }
  
  var body: some View {
    VStack(spacing: 16) {
      selectFile
      declPicker
      saveFile
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  var selectFile: some View {
    HStack(spacing: 16) {
      Text(chosenFilename)
      Spacer()
      Button("Select File", action: onTapSelectFile)
    }
  }
  
  var declPicker: some View {
    HSplitView {
      VStack {
        Table(decls, selection: $selectedDecls) {
          TableColumn("Rewriteable Types", value: \.name)
        }
        HStack {
          Button("Select All") {
            selectedDecls = Set(decls.map({$0.id}))
          }.disabled(selectedDecls.count == decls.count)
          Button("Deselect All") {
            selectedDecls.removeAll()
          }.disabled(selectedDecls.isEmpty)
          Spacer()
        }
      }
      .frame(minWidth: 200)
      .padding()
      VStack {
        HStack {
          Text("File Content:")
          Spacer()
        }
        TextEditor(text: .constant(fileContent))
      }
      .frame(minWidth: 200)
      .padding()
    }
  }
  
  var saveFile: some View {
    Button("Save As...", action: onTapSaveAs)
      .disabled(selectedDecls.isEmpty)
  }
  
  func onTapSelectFile() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    if panel.runModal() == .OK {
      self.chosenURL = panel.url
    }
  }
  
  func onTapSaveAs() {
    
  }
  
}

struct Decl: Hashable, Identifiable {
  
  let name: String
  
  let id: UUID = UUID()
  
}

struct ContentView_Previews: PreviewProvider {
  
  static var previewDecls: [Decl] {
    [
      Decl(name: "Foo"),
      Decl(name: "Bar"),
      Decl(name: "Fee"),
      Decl(name: "Foe"),
      Decl(name: "Fum"),
    ]
  }
  
  static var previews: some View {
    ContentView(decls:  previewDecls)
  }
}
