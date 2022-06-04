//
//  SessionManager.swift
//  COWRewriter
//
//  Created by WeZZard on 6/4/22.
//

import Foundation
import Combine

class SessionManager: ObservableObject {
  
  @Published
  var selectedFileURL: URL?
  
  @Published
  var currentSession: Session?
  
  @Published
  var importErrorMessage: String?
  
  init() {
    $selectedFileURL
      .receive(on: DispatchQueue.main).map(makeSession)
      .assign(to: &$currentSession)
  }
  
  private func makeSession(url: URL?) -> Session? {
    guard let url = url else {
      return nil
    }
    
    do {
      return try Session(fileUrl: url)
    } catch let error as Refactorer.InitializationError {
      importErrorMessage = error.description
    } catch let error {
      importErrorMessage = error.localizedDescription
    }
    
    return nil
  }
  
}
