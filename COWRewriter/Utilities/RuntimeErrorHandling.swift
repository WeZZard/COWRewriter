//
//  RuntimeErrorHandling.swift
//  COWRewriter
//
//  Created by WeZZard on 6/1/22.
//

import OSLog

func notImplemented() -> Never {
  fatalError()
}

func abstract() -> Never {
  fatalError()
}

func unreachable() -> Never {
  fatalError()
}
