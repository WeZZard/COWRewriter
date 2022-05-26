struct Foo {

  var value1: Int
  
  var value2 = 0
  
  var value3 = 0, value4 = 0
  
  var value5 = Bar.makeBar()

  var value6 = Foo.makeFoo()

  init(value1: Int, value2: Int, value3: Int, value4: Int, value5: Int, value6: Foo) {
      self.value1 = value1
      self.value2 = value2
      self.value3 = value3
      self.value4 = value4
      self.value5 = value5
      self.value6 = value6
  }

}

struct Foo {


    static func makeFoo() -> Foo { Foo() }

}
