//
//  RefactorView.swift
//  COWRewriter
//
//  Created by WeZZard on 6/4/22.
//

import SwiftUI

struct RefactorView: View {
  
  @Binding
  var selectedFileURL: URL?
  
  @EnvironmentObject
  var session: Session
  
  var body: some View {
    FilePicker(selectedFileURL: $selectedFileURL)
    RefactorRequestsConfigView(
      candidates: $session.candidates,
      selectedCandidates: $session.selectedCandidates,
      refactorRequestConfigs: $session.refactorRequestConfigs,
      printerConfigs: $session.printerConfigs,
      contentsPreview: $session.contentsPreview
    )
    BottomToolbar(
      actions: session,
      candidates: $session.candidates,
      refactorRequests: $session.refactorRequests
    )
  }
  
}
