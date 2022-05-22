//
//  XCTestCase+COWRewriterTestsAdditions.swift
//  COWRewriterTests
//
//  Created by WeZZard on 5/22/22.
//

import XCTest

extension XCTestCase {
  
  /// Asserts that the two strings are equal, providing Unix `diff`-style output if they are not.
  ///
  /// - Parameters:
  ///   - actual: The actual string.
  ///   - expected: The expected string.
  ///   - message: An optional description of the failure.
  ///   - file: The file in which failure occurred. Defaults to the file name of the test case in
  ///     which this function was called.
  ///   - line: The line number on which failure occurred. Defaults to the line number on which this
  ///     function was called.
  internal func XCTAssertStringsEqualWithDiff(
    _ actual: String,
    _ expected: String,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let actualLines = actual.components(separatedBy: .newlines)
    let expectedLines = expected.components(separatedBy: .newlines)

    let difference = actualLines.difference(from: expectedLines)
    if difference.isEmpty { return }

    var result = ""

    var insertions = [Int: String]()
    var removals = [Int: String]()

    for change in difference {
      switch change {
      case .insert(let offset, let element, _):
        insertions[offset] = element
      case .remove(let offset, let element, _):
        removals[offset] = element
      }
    }

    var expectedLine = 0
    var actualLine = 0

    while expectedLine < expectedLines.count || actualLine < actualLines.count {
      if let removal = removals[expectedLine] {
        result += "-\(removal)\n"
        expectedLine += 1
      } else if let insertion = insertions[actualLine] {
        result += "+\(insertion)\n"
        actualLine += 1
      } else {
        result += " \(expectedLines[expectedLine])\n"
        expectedLine += 1
        actualLine += 1
      }
    }

    let failureMessage = "Actual output (+) differed from expected output (-):\n\(result)"
    let fullMessage = message.isEmpty ? failureMessage : "\(message) - \(failureMessage)"
    XCTFail(fullMessage, file: file, line: line)
  }
  
}
