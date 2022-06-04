//
//  ImportErrorMessageView.swift
//  COWRewriter
//
//  Created by WeZZard on 6/4/22.
//

import SwiftUI

struct ImportErrorMessageView: View {
  
  @Binding
  var importErrorMessage: String?
  
  let fadeEdge: Edge
  
  var body: some View {
    if let importErrorMessage = importErrorMessage {
      HStack {
        Image(systemName: "xmark.octagon.fill")
          .foregroundColor(.yellow)
        Text(importErrorMessage)
        Button(action: onTapClearImportErrorMessage) {
          Image(systemName: "xmark.circle")
        }.buttonStyle(.borderless)
      }
      .transition(.opacity.combined(with: .move(edge: fadeEdge)))
    }
  }
  
  private func onTapClearImportErrorMessage() {
    animatedImportErrorMessage.wrappedValue = nil
  }
  
  private var animatedImportErrorMessage: Binding<String?> {
    $importErrorMessage.animation(.easeInOut)
  }
  
}
