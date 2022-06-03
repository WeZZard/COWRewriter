//
//  NameLookUpRequest.swift
//  COWRewriter
//
//  Created by WeZZard on 6/3/22.
//


// A name lookup request
struct NameLookUpRequest {
  
  let name: String
  
  let members: MemberAccessPath
  
  init(name: String) {
    self.name = name
    self.members = MemberAccessPath()
  }
  
  init(name: String, members: String ...) {
    self.name = name
    self.members = MemberAccessPath(members: members)
  }
  
  init(name: String, members: MemberAccessPath) {
    self.name = name
    self.members = members
  }
  
  static func make(name: String) -> NameLookUpRequest {
    return NameLookUpRequest(name: name)
  }
  
  func accessing(_ member: String) -> NameLookUpRequest {
    return NameLookUpRequest(name: self.name, members: members.appending(member))
  }
  
}

struct MemberAccessPath: RandomAccessCollection {
  
  let members: [String]
  
  init() {
    self.members = []
  }
  
  init(members: [String]) {
    self.members = members
  }
  
  func dequeueingFirst() -> MemberAccessPath {
    MemberAccessPath(members: Array(members.dropFirst()))
  }
  
  func appending(_ member: String) -> MemberAccessPath {
    precondition(!member.contains("."))
    return MemberAccessPath(members: members + [member])
  }
  
  var startIndex: Int {
    members.startIndex
  }
  
  var endIndex: Int {
    members.endIndex
  }
  
  func index(after i: Int) -> Int {
    members.index(after: i)
  }
  
  func index(_ i: Int, offsetBy distance: Int) -> Int {
    members.index(i, offsetBy: distance)
  }
  
  subscript(position: Int) -> String {
    _read {
      yield members[position]
    }
  }
  
}

extension MemberAccessPath: ExpressibleByArrayLiteral {
  
  typealias ArrayLiteralElement = String
  
  init(arrayLiteral elements: ArrayLiteralElement...) {
    self.init(members: elements)
  }
  
}
