//
//  ConditionalKeyboardShorcut.swift
//  COWRewriter
//
//  Created by WeZZard on 6/5/22.
//

import SwiftUI


extension View {
  
  func keyboardShortcut(
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


struct ConditionalKeyboardShorcut: ViewModifier {
  
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
