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
  
  var body: some View {
    refactorViewOrFileDropView
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  @ViewBuilder
  var refactorViewOrFileDropView: some View {
    if let session = sessionManager.currentSession {
      RefactorView(selectedFileURL: $sessionManager.selectedFileURL)
        .environmentObject(session)
        .transition(.opacity)
    } else {
      FileDropView(selectedFileURL: $sessionManager.selectedFileURL)
        .transition(.opacity)
    }
  }
  
}

struct ContentView_Previews: PreviewProvider {
  
  static var previews: some View {
    ContentView()
  }
}
