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
  private var refactorer: Refactorer?
  
  @State
  private var importErrorMessage: String?
  
  @State
  private var decls: [Decl] = []
  
  @State
  private var selectedDecls: Set<Decl> = []
  
  @State
  private var refactorRequests: [RefactorRequest] = []
  
  private let printer: PrettyPrinter = PrettyPrinter()
  
  var body: some View {
    VStack(spacing: 16) {
      if refactorer == nil {
        standByView
          .transition(.opacity)
      } else {
        refactorView
          .transition(.opacity)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onChange(of: selectedFileURL, perform: onSelectedFileUrlChange)
  }
  
  @ViewBuilder
  private var standByView: some View {
    VStack {
      Spacer()
      VStack(spacing: 8) {
        HStack {
          Button("Open", action: onTapOpen)
          Text("a file or drag & drop it here.")
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
        }
        if let importErrorMessage = importErrorMessage {
          HStack {
            Image(systemName: "xmark.octagon.fill")
              .foregroundColor(.yellow)
            Text(importErrorMessage)
            Button(action: onTapClearImportErrorMessage) {
              Image(systemName: "xmark.circle")
            }.buttonStyle(.borderless)
          }
          .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
      }
      .padding(32)
      Spacer()
    }
    .onDrop(
      of: [.fileURL],
      isTargeted: nil,
      perform: FilePicker.onDrop(
        url: $selectedFileURL.animation(.spring()),
        errorMessage: animatedImportErrorMessage
      )
    )
  }
  
  @ViewBuilder
  private var refactorView: some View {
    FilePicker(url: $selectedFileURL)
    RefactorConfigView(
      fileURL: $selectedFileURL,
      refactorer: $refactorer,
      decls: $decls,
      selectedDecls: $selectedDecls,
      refactorRequests: $refactorRequests
    )
    BottomToolbar(
      decls: $decls,
      refactorRequests: $refactorRequests,
      refactorer: refactorer,
      printer: printer
    )
  }
  
  private var animatedImportErrorMessage: Binding<String?> {
    self.$importErrorMessage.animation(.spring())
  }
  
  private func onSelectedFileUrlChange(_ url: URL?) {
    do {
      self.refactorer = try url.flatMap(Refactorer.init)
    } catch let error as Refactorer.InitializationError {
      animatedImportErrorMessage.wrappedValue = error.description
    } catch let error {
      animatedImportErrorMessage.wrappedValue = error.localizedDescription
    }
  }
  
  private func onTapOpen() {
    if let url = FilePicker.open() {
      withAnimation(.spring()) {
        self.selectedFileURL = url
      }
    }
  }
  
  private func onTapClearImportErrorMessage() {
    animatedImportErrorMessage.wrappedValue = nil
  }
  
}

struct ContentView_Previews: PreviewProvider {
  
  static var previews: some View {
    ContentView()
  }
}
