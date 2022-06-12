//
//  FileDropView.swift
//  COWRewriter
//
//  Created by WeZZard on 6/4/22.
//

import SwiftUI

struct FileDropView: View {
  
  @Binding
  var selectedFileURL: URL?
  
  @State
  private var importErrorMessage: String?
  
  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Button("Open", action: onTapOpen)
          .fixedSize()
        Text("or drop a Swift source file.")
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: true)
      }
      ImportErrorMessageView(
        importErrorMessage: $importErrorMessage,
        fadeEdge: .bottom
      )
    }
    .frame(
      minWidth: 300,
      maxWidth: .infinity,
      minHeight: 150,
      maxHeight: .infinity
    )
    .onDrop(
      of: [.fileURL],
      isTargeted: nil,
      perform: FilePicker.onDrop(
        url: animatedSelectedFileURL,
        errorMessage: animatedImportErrorMessage
      )
    )
  }
  
  private var animatedImportErrorMessage: Binding<String?> {
    $importErrorMessage.animation(.easeInOut)
  }
  
  private var animatedSelectedFileURL: Binding<URL?> {
    $selectedFileURL.animation(.easeInOut)
  }
  
  private func onTapOpen() {
    guard let url = FilePicker.open() else {
      return
    }
    animatedSelectedFileURL.wrappedValue = url
  }
  
}
