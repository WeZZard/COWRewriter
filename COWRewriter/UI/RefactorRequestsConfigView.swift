//
//  RefactorRequestsConfigView.swift
//  COWRewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI

struct RefactorRequestsConfigView: View {
  
  @Binding
  var candidates: [RefactorCandidate]
  
  @Binding
  var selectedCandidates: Set<UUID>
  
  @Binding
  var refactorRequestConfigs: [RefactorRequestConfig]
  
  @Binding
  var printerConfigs: PrinterConfigs
  
  @Binding
  var contentsPreview: String
  
  @State
  private var highlightedDeclID: UUID? = nil
  
  @State
  private var showPreviewOptions: Bool = false
  
  @State
  private var showUnresolvedSemanticsList: Bool = false
  
  var body: some View {
    HSplitView {
      refactorableTypeList
        .minSizeBoundedSplitContent(at: .first)
      if showUnresolvedSemanticsList {
        unresolvedSemanticsList
          .minSizeBoundedSplitContent(at: .intermediate)
      }
      refactorPreviewView
        .minSizeBoundedSplitContent(at: .last)
    }
    .onChange(of: highlightedDeclID, perform: onHighlightedDeclIDChange)
    .onChange(of: selectedCandidates) { _ in
      updateSplitContents()
    }
    .onAppear {
      updateSplitContents()
    }
  }
  
  @ViewBuilder
  private var refactorableTypeList: some View {
    VStack {
      ColumnLabel {
        Text("Refactorable Types")
          .font(.system(.callout))
      }
      .padding(8)
      Table($candidates, selection: $highlightedDeclID) {
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
        ForEach($refactorRequestConfigs.filter(isOfSelectedCandidate)) { $group in
          Section("struct \(group.declName)") {
            ForEach($group.unresolvedSemanticsItems) { $item in
              UnresolvedSemanticsItemView($item)
            }
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .border(Color.secondary)
    }
  }
  
  @ViewBuilder
  private var refactorPreviewView: some View {
    VStack {
      HStack {
        ColumnLabel {
          Text("Preview")
            .font(.system(.callout))
        }
        Spacer()
        Toggle("Options", isOn: $showPreviewOptions.animation())
          .toggleStyle(.button)
      }
      .padding(8)
      VStack {
        if showPreviewOptions {
          previewOptionsView
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        TextEditor(text: .constant(contentsPreview))
          .frame(maxWidth: .infinity)
          .font(Font.system(.body).monospaced())
          .lineLimit(nil)
          .border(Color.secondary)
      }.clipped()
    }
  }
  
  @ViewBuilder
  private var previewOptionsView: some View {
    VStack(alignment: .leading) {
      Picker("Prefer Indent Using: ", selection: $printerConfigs.indentationMode) {
        ForEach(PrinterConfigs.IndentationMode.allCases, id: \.self) { eachCase in
          Text(eachCase.displayName)
        }
      }
      HStack {
        Text("Tab Width: ")
        Stepper(value: $printerConfigs.tabWidth, in: 1...(.max)) {
          TextField(
            "",
            text: Binding {
              String(printerConfigs.tabWidth)
            } set: { newValue in
              guard let newIntValue = Int(newValue) else {
                return
              }
              printerConfigs.tabWidth = newIntValue
            }
          ).frame(maxWidth: 20)
        }
        Text("spaces")
      }
      HStack {
        Text("Indent Width: ")
        Stepper(value: $printerConfigs.indentWidth, in: 1...(.max)) {
          TextField(
            "",
            text: Binding {
              String(printerConfigs.indentWidth)
            } set: { newValue in
              guard let newIntValue = Int(newValue) else {
                return
              }
              printerConfigs.indentWidth = newIntValue
            }
          ).frame(maxWidth: 20)
        }
        Text("spaces")
      }
    }
  }
  
  private func onHighlightedDeclIDChange(_ id: UUID?) {
    guard let id = id else {
      return
    }
    updateHighlightId(id)
  }
  
  private func isOfSelectedCandidate(_ config: RefactorRequestConfig) -> Bool {
    selectedCandidates.contains(config.id)
  }
  
  private func isOfSelectedCandidate(_ config: Binding<RefactorRequestConfig>) -> Bool {
    selectedCandidates.contains(config.id)
  }
  
  private func updateSplitContents() {
    showUnresolvedSemanticsList = refactorRequestConfigs
      .filter(isOfSelectedCandidate)
      .reduce(false) { partial, config in
        partial || !config.unresolvedSemanticsItems.isEmpty
      }
  }
  
  private func updateHighlightId(_ id: UUID) {
    
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

private enum UnresolvedSemanticsItemView: View {
  
  typealias Item = RefactorRequestConfig.UnresolvedSemanticsItem
  
  case name(NamingIssueView)
  
  case typeAnnotation(TypeAnnotationIssueView)
  
  var body: some View {
    switch self {
    case let .name(view):
      view
    case let .typeAnnotation(view):
      view
    }
  }
  
  init(_ item: Binding<Item>) {
    switch item.wrappedValue {
    case let .name(issue):
      self = .name(
        NamingIssueView(
          issue: Binding(
            get: { issue },
            set: { newValue, transaction in
              item.wrappedValue = .name(newValue)
            }
          )
        )
      )
    case let .typeAnnotation(issue):
      self = .typeAnnotation(
        TypeAnnotationIssueView(
          issue: Binding(
            get: { issue },
            set: { newValue, transaction in
              item.wrappedValue = .typeAnnotation(newValue)
            }
          )
        )
      )
    }
  }
  
  struct NamingIssueView: View {
    
    typealias Issue = Item.NamingIssue
    
    @Binding
    var issue: Issue
    
    var body: some View {
      VStack(alignment: .leading) {
        Text(issue.key.rawValue)
        TextField(
          issue.suggestedName ?? "",
          text: $issue.userSpecifiedName
        )
      }
    }
    
  }
  
  struct TypeAnnotationIssueView: View {
    
    typealias Issue = Item.TypeAnnotationIssue
    
    @Binding
    var issue: Issue
    
    var body: some View {
      VStack(alignment: .leading) {
        Text("\(issue.letOrVar) \(issue.name): ")
        TextField(
          issue.suggestedType?.description ?? "Missing type",
          text: $issue.userType
        )
      }
    }
    
  }
  
}
