//
//  ContentView.swift
//  COW Rewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI

struct ContentView: View {
  
  @State
  private var selectedFileURL: URL?
  
  @State
  private var context: RewriteContext?
  
  @State
  var decls: [Decl] = []
  
  @State
  private var selectedDecls: Set<Decl> = []
  
  var body: some View {
    VStack(spacing: 16) {
      if selectedFileURL == nil {
        noUrlView
          .transition(.opacity)
      } else {
        hasUrlView
          .transition(.opacity)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onChange(of: selectedFileURL, perform: onSelectedFileUrlChange)
    .onDrop(
      of: [.fileURL],
      isTargeted: nil,
      perform: FilePicker.onDrop(url: $selectedFileURL.animation(.spring()))
    )
  }
  
  @ViewBuilder
  private var hasUrlView: some View {
    FilePicker(url: $selectedFileURL)
    DeclPicker(
      fileURL: $selectedFileURL,
      rewriteContext: $context,
      decls: $decls,
      selectedDecls: $selectedDecls
    )
    BottomToolbar(
      decls: $decls,
      selectedDecls: $selectedDecls,
      rewriteContext: context
    )
  }
  
  @ViewBuilder
  private var noUrlView: some View {
    VStack {
      Spacer()
      VStack {
        Button("Open", action: onTapOpen)
          .padding(.bottom, 8)
        Text("Open a file or drag & drop it here.")
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: true)
      }
      .padding(32)
      Spacer()
    }
  }
  
  private func onSelectedFileUrlChange(_ url: URL?) {
    let context = url.map(RewriteContext.init)
    self.context = context
  }
  
  private func onTapOpen() {
    if let url = FilePicker.open() {
      withAnimation(.spring()) {
        self.selectedFileURL = url
      }
    }
  }
  
}

struct ContentView_Previews: PreviewProvider {
  
  static var previews: some View {
    ContentView()
  }
}
