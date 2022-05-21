//
//  DeclPicker.swift
//  COWRewriter
//
//  Created by WeZZard on 5/21/22.
//

import SwiftUI

struct DeclPicker: View {
  
  @Binding
  var fileURL: URL?
  
  @Binding
  var rewriteContext: RewriteContext?
  
  @Binding
  var decls: [Decl]
  
  @Binding
  var selectedDecls: Set<Decl>
  
  @State
  private var fileContent: String = ""
  
  @State
  private var highlightedDeclID: UUID? = nil
  
  var body: some View {
    HSplitView {
      declList
        .frame(minWidth: 300, minHeight: 500)
        .padding(.trailing, 8)
      fileContentPreview
        .frame(minWidth: 300, minHeight: 500)
        .padding(.leading, 8)
    }
    .onChange(of: fileURL, perform: onFileURLChange)
    .onChange(of: rewriteContext, perform: onRewriterContextChange)
    .onChange(of: decls, perform: onDeclsChange)
    .onChange(of: highlightedDeclID, perform: onHighlightedDeclIDChange)
    .onAppear(perform: onAppear)
  }
  
  @ViewBuilder
  private var declList: some View {
    VStack {
      // TODO: space to select highlighted row
      HStack {
        Text("Rewritable Types")
          .font(.system(.callout))
        Spacer()
      }
      .padding(8)
      Table($decls, selection: $highlightedDeclID) {
        TableColumn("Rewrite") { $decl in
          HStack {
            Spacer()
            Toggle(isOn: $decl.isSelected, label: { })
              .keyboardShortcut(
                .space,
                modifiers: [],
                when: highlightedDeclID == $decl.wrappedValue.id
              )
              .labelsHidden()
            Spacer()
          }
        }
        .width(50)
        TableColumn("Type Name", value: \.wrappedValue.rewritableDecl.name)
      }
      .border(Color.secondary)
    }
  }
  
  @ViewBuilder
  private var fileContentPreview: some View {
    VStack {
      HStack {
        Text("Source File Contents")
          .font(.system(.callout))
        Spacer()
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
  
  private func onFileURLChange(_ url: URL?) {
    applyURL(url)
  }
  
  private func onRewriterContextChange(_ rewriteContext: RewriteContext?) {
    applyRewriteContext(rewriteContext)
  }
  
  private func onAppear() {
    applyURL(fileURL)
    applyRewriteContext(rewriteContext)
  }
  
  private func applyURL(_ url: URL?) {
    Task {
      fileContent = try url.map({try String(contentsOfFile: $0.path)}) ?? ""
    }
  }
  
  private func applyRewriteContext(_ rewriteContext: RewriteContext?) {
    // FIXME: Queue and cancellation on disappear
    Task {
      let decls = await rewriteContext?.rewritableDecls
      self.decls = decls?.map(Decl.init) ?? []
    }
  }
  
  private func applyHighlight(id: UUID) {
    
  }
  
}


struct Decl: Hashable, Identifiable {
  
  let rewritableDecl: RewritableDecl
  
  let id: UUID = UUID()
  
  var isSelected: Bool = false
  
  init(rewritableDecl: RewritableDecl) {
    self.rewritableDecl = rewritableDecl
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
    content
      .keyboardShortcut(isAvailable ? keyboardShortcut : nil)
  }
  
}
