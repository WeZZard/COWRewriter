//
//  RefactorConfigView.swift
//  COWRewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI

struct RefactorConfigView: View {
  
  @Binding
  var fileURL: URL?
  
  @Binding
  var refactorer: Refactorer?
  
  @Binding
  var decls: [Decl]
  
  @Binding
  var selectedDecls: Set<Decl>
  
  @Binding
  var refactorRequests: [RefactorRequest]
  
  @State
  private var fileContent: String = ""
  
  @State
  private var refactorConfigGroups: [RefactorConfigGroup] = []
  
  @State
  private var highlightedDeclID: UUID? = nil
  
  var body: some View {
    HSplitView {
      refactorableTypeList
        .minSizeBoundedSplitContent(at: .first)
      unresolvedSemanticsList
        .minSizeBoundedSplitContent(at: .intermediate)
      refactorPreviewView
        .minSizeBoundedSplitContent(at: .last)
    }
    .onChange(of: fileURL, perform: onFileURLChange)
    .onChange(of: refactorer, perform: onRewriterContextChange)
    .onChange(of: decls, perform: onDeclsChange)
    .onChange(of: highlightedDeclID, perform: onHighlightedDeclIDChange)
    .onChange(of: selectedDecls, perform: onSelectedDeclsChange)
    .onAppear(perform: onAppear)
  }
  
  @ViewBuilder
  private var refactorableTypeList: some View {
    VStack {
      ColumnLabel {
        Text("Refactorable Types")
          .font(.system(.callout))
      }
      .padding(8)
      Table($decls, selection: $highlightedDeclID) {
        TableColumn("Refactor") { $decl in
          TableColumnContentToggle(
            isOn: $decl.isSelected,
            isAvailable: highlightedDeclID == $decl.wrappedValue.id
          )
        }
        .width(50)
        TableColumn("Type Name", value: \.wrappedValue.content.identifier)
      }
      .border(Color.secondary)
    }
  }
  
  @ViewBuilder
  private var unresolvedSemanticsList: some View {
    VStack {
      ColumnLabel {
        Text("Unresolved Semantics")
          .font(.system(.callout))
      }
      .padding(8)
      List {
        ForEach(refactorConfigGroups) { group in
          group
        }
      }
      .border(Color.secondary)
    }
  }
  
  @ViewBuilder
  private var refactorPreviewView: some View {
    VStack {
      ColumnLabel {
        Text("Preview")
          .font(.system(.callout))
      }
      .padding(8)
      TextEditor(text: .constant(fileContent))
        .frame(maxWidth: .infinity)
        .font(Font.system(.body).monospaced())
        .lineLimit(nil)
        .border(Color.secondary)
    }
  }
  
  private func onDeclsChange(_ decls: [Decl]) {
    selectedDecls = Set(decls.filter(\.isSelected))
  }
  
  private func onHighlightedDeclIDChange(_ id: UUID?) {
    guard let id = id else {
      return
    }
    applyHighlight(id: id)
  }
  
  private func onSelectedDeclsChange(_ decls: Set<Decl>) {
    refactorConfigGroups = decls
      .sorted(by: \.content.identifier)
      .map(\.content)
      .map(RefactorConfigGroup.init)
  }
  
  private func onFileURLChange(_ url: URL?) {
    applyURL(url)
  }
  
  private func onRewriterContextChange(_ refactorer: Refactorer?) {
    applyRefactorer(refactorer)
  }
  
  private func onAppear() {
    applyURL(fileURL)
    applyRefactorer(refactorer)
  }
  
  private func applyURL(_ url: URL?) {
    Task {
      fileContent = try url.map({try String(contentsOfFile: $0.path)}) ?? ""
    }
  }
  
  private func applyRefactorer(_ refactorer: Refactorer?) {
    // FIXME: Queue and cancellation on disappear
    Task {
      let decls = await refactorer?.refactorableDecls
      self.decls = decls?.map(Decl.init) ?? []
    }
  }
  
  private func applyHighlight(id: UUID) {
    
  }
  
}


struct Decl: Hashable, Identifiable {
  
  let content: RefactorableDecl
  
  let id: UUID = UUID()
  
  var isSelected: Bool = false
  
  init(content: RefactorableDecl) {
    self.content = content
  }
  
}

extension View {
  
  fileprivate func keyboardShortcut(
    _ key: KeyEquivalent,
    modifiers: EventModifiers = .command,
    when isAvailable: Bool
  ) -> some View {
    modifier(
      ConditionalKeyboardShorcut(
        isAvailable: isAvailable,
        keyboardShortcut: KeyboardShortcut(key, modifiers: modifiers)
      )
    )
  }
  
}

private struct ConditionalKeyboardShorcut: ViewModifier {
  
  let isAvailable: Bool
  
  let keyboardShortcut: KeyboardShortcut
  
  func body(content: Content) -> some View {
    if isAvailable {
      content
        .keyboardShortcut(
          keyboardShortcut.key,
          modifiers: keyboardShortcut.modifiers,
          localization: keyboardShortcut.localization
        )
    } else {
      content
    }
  }
  
}


private enum SplitContentPosition {
  case first
  case intermediate
  case last
  
  var edges: Edge.Set {
    switch self {
    case .first:        return .trailing
    case .intermediate: return [.leading, .trailing]
    case .last:         return .leading
    }
  }
  
}

extension View {
  
  fileprivate func minSizeBoundedSplitContent(
    at position: SplitContentPosition
  ) -> some View {
    frame(minWidth: 300, minHeight: 500)
      .padding(position.edges, 8)
  }
  
}

private struct ColumnLabel<Label: View>: View {
  
  let label: Label
  
  init(@ViewBuilder label: () -> Label) {
    self.label = label()
  }
  
  var body: some View {
    HStack {
      label
        .font(.system(.callout))
      Spacer()
    }
  }
  
}

private struct TableColumnContentToggle: View {
  
  @Binding
  var isOn: Bool
  
  let isAvailable: Bool
  
  var body: some View {
    HStack {
      Spacer()
      Toggle(isOn: $isOn, label: { })
        .keyboardShortcut(.space, modifiers: [], when: isAvailable)
        .labelsHidden()
      Spacer()
    }
  }

}

private struct RefactorConfigGroup: View, Identifiable {
  
  var isSelected: Bool
  
  let declName: String
  
  var items: [RefactorConfigItem]
  
  init(refactorableDecl decl: RefactorableDecl) {
    isSelected = false
    declName = decl.identifier
    items = [
      .storageClassName(suggestedName: decl.suggestedStorageClassName, userName: State(initialValue: "")),
      .makeUniqueFunctionName(suggestedName: decl.suggestedMakeUniqueStorageFunctionName, userName: State(initialValue: "")),
    ] + decl.uninferrablePatternBindings.map { binding in
        .uninferrableType(letOrVar: binding.letOrVar, name: binding.identifier, suggestedType: binding.maybeType, userType: State(initialValue: ""))
    }
  }
  
  var body: some View {
    Section("struct \(declName)") {
      ForEach(items) { item in
        item
      }
    }
  }
  
  var id: Int {
    var hasher = Hasher()
    hasher.combine(declName)
    return hasher.finalize()
  }
  
}

private enum RefactorConfigItem: View, Identifiable {
  
  case storageClassName(suggestedName: String, userName: State<String>)
  
  case makeUniqueFunctionName(suggestedName: String, userName: State<String>)
  
  case uninferrableType(letOrVar: String, name: String, suggestedType: String?, userType: State<String>)
  
  var body: some View {
    switch self {
    case .storageClassName(let suggestedName, let userName):
      VStack(alignment: .leading) {
        Text("Storage Class Name:")
        TextField(suggestedName, text: userName.projectedValue)
      }
    case .makeUniqueFunctionName(let suggestedName, let userName):
      VStack(alignment: .leading) {
        Text("Make Unique Storage Function Name:")
        TextField(suggestedName, text: userName.projectedValue)
      }
    case .uninferrableType(let letOrVar, let name, let suggestedType, let userType):
      VStack(alignment: .leading) {
        Text("\(letOrVar) \(name): ")
        TextField(suggestedType ?? "Missing type", text: userType.projectedValue)
      }
    }
  }
  
  var id: Int {
    var hasher = Hasher()
    switch self {
    case .storageClassName(_, _):
      hasher.combine(0)
    case .makeUniqueFunctionName(_, _):
      hasher.combine(1)
    case .uninferrableType(_, let name, _, _):
      hasher.combine(2)
      hasher.combine(name)
    }
    return hasher.finalize()
  }
  
}
