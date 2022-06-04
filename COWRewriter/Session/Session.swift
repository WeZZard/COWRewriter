//
//  Session.swift
//  COWRewriter
//
//  Created by WeZZard on 6/4/22.
//

import Foundation
import Combine
import AppKit
import SwiftUI


class Session: ObservableObject, BottomToolbarActions {
  
  let fileUrl: URL
  
  @Published
  var candidates: [RefactorCandidate]
  
  @Published
  var selectedCandidates: Set<UUID>
  
  @Published
  var refactorRequestConfigs: [RefactorRequestConfig]
  
  @Published
  var contentsPreview: String
  
  @Published
  var refactorRequests: [RefactorRequest]
  
  private let refactorer: Refactorer
  
  private let printer: PrettyPrinter
  
  private var disposables: Set<AnyCancellable>
  
  init(fileUrl: URL) throws {
    self.fileUrl = fileUrl
    self.candidates = []
    self.selectedCandidates = []
    self.refactorRequestConfigs = []
    self.refactorRequests = []
    self.contentsPreview = ""
    self.refactorer = try Refactorer(url: fileUrl)
    self.printer = PrettyPrinter()
    self.disposables = []
    setUp()
  }
  
  private func setUp() {
    $candidates
      .debounce(for: 0.1, scheduler: DispatchQueue.main)
      .receive(on: DispatchQueue.main)
      .map({Set($0.filter(\.isSelected).map(\.id))})
      .assign(to: &$selectedCandidates)
      
    $selectedCandidates
      .combineLatest($refactorRequestConfigs)
      .receive(on: DispatchQueue.main)
      .map { (selectedCandidates, configs) in
        configs
          .filter({selectedCandidates.contains($0.id)})
          .map(\.request)
      }
      .assign(to: &$refactorRequests)
    
    $refactorRequests.receive(on: DispatchQueue.main)
      .sink(receiveValue: updateRefactorResults)
      .store(in: &disposables)
    
    Task {
      let refactorableDecls = await refactorer.refactorableDecls
      await updateCandidates(refactorableDecls.map(RefactorCandidate.init))
    }
    
    updateRefactorResults(refactorRequests)
  }
  
  private func updateRefactorResults(_ requests: [RefactorRequest]) {
    Task {
      let contents = printer.print(await refactorer.refactor(refactorRequests))
      await updateContentsPreview(contents)
    }
  }
  
  @Sendable
  @MainActor
  private func updateCandidates(_ candidates: [RefactorCandidate]) {
    self.candidates = candidates
    self.refactorRequestConfigs = candidates.map(RefactorRequestConfig.init)
  }
  
  @Sendable
  @MainActor
  private func updateContentsPreview(_ contents: String) {
    self.contentsPreview = contents
  }
  
  func selectAll() {
    for index in candidates.indices {
      candidates[index].isSelected = true
    }
  }
  
  func deselectAll() {
    for index in candidates.indices {
      candidates[index].isSelected = false
    }
  }
  
  func copy() async {
    let contents = await refactorer.refactor(refactorRequests)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(printer.print(contents), forType: .string)
  }
  
  func saveAs(url: URL) async throws {
    let syntax = await refactorer.refactor(refactorRequests)
    let text = printer.print(syntax)
    try text.data(using: .utf8)?.write(to: url)
  }
  
}
