//
//  ContentView.swift
//  COW Rewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI

struct ContentView: View {
  
  @EnvironmentObject
  var sessionManager: SessionManager
  
  @State
  private var importErrorMessage: String?
  
  var body: some View {
    VStack(spacing: 16) {
      if let session = sessionManager.currentSession {
        RefactorView(selectedFileURL: $sessionManager.selectedFileURL)
          .environmentObject(session)
          .transition(.opacity)
      } else {
        FileDropView(selectedFileURL: $sessionManager.selectedFileURL)
          .transition(.opacity)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
}

struct ContentView_Previews: PreviewProvider {
  
  static var previews: some View {
    ContentView()
  }
}
