//
//  COWRewriter.swift
//  COWRewriter
//
//  Created by WeZZard on 5/26/22.
//

import SwiftSyntax
import SwiftSyntaxBuilder

protocol COWRewriterInputContext: AnyObject {
  
  var file: String? { get }
  
  var tree: Syntax { get }
  
  var slc: SourceLocationConverter { get }
  
}

class COWRewriter {
  
  unowned let input: COWRewriterInputContext
  
  init(input: COWRewriterInputContext) {
    self.input = input
  }
  
  func execute(requests: [RefactorRequest]) -> Syntax {
    let concrete = COWRewriterConcrete(slc: input.slc, requests: requests)
    return concrete.visit(input.tree)
  }
  
}

/**
 --- Create Storage Class ------------------------------------------------------
 - Collect struct nested types -> resolve final name for the `Storage` class.
 - Collect struct stored properties.
 - `Storage`'s memberwise initializer shall take default value into consideration.
 -------------------------------------------------------------------------------
 1. Create a storage class, say `Storage`.
 2. Copy all the stored property of the `struct` to `Storage`.
 3. Collect all initializers of the `struct` and copy to `Storage`.
 4. Create the memberwrise initializer for `Storage` if needed.
 5. Create a copy initializer for `Storage`.
 --- Rewrite Struct Decl -------------------------------------------------------
 - Collect struct members
 -> resolve final name for the `storage` variable.
 -> resolve final name for the `makeUniquelyReferencedStorage` function.
 -> resolve if it is necessary to create the memberwise initializer
 -> resolve how many initializers here are needed to be copied to `Storage`
 -------------------------------------------------------------------------------
 6. Create a storage stored property in `struct`, say `storage`.
 7. Create a storage unique-ify function, say `makeUniquelyReferencedStorage`, in `struct`.
 8. Rewrite all the stored properties in `struct` (except the `storage`) with dispatch call to relative properties in `storage`
 9. Create the memberwrise initializer for `struct` if needed.
 10. Rewrite all the initializers in `struct` with dispatch call to relative initializers in `Storage`
 */

private class COWRewriterConcrete: SyntaxRewriter {
  
  let slc: SourceLocationConverter
  
  let requests: [RefactorRequest]
  
  init(slc: SourceLocationConverter, requests: [RefactorRequest]) {
    self.slc = slc
    self.requests = requests
  }
  
}

private func rewriteStruct(
  struct: StructDeclSyntax,
  storageClass: ClassDeclSyntax,
  makeUniqueStorageFunctionName: String
) -> StructDeclSyntax {
  notImplemented()
}

enum StorageClassCreationError: Error {
  
  case noInferredTypeAndUserType(storageName: String)
  
}

private func makeStorageClass(
  structType: StructDeclSyntax,
  className: String,
  storedProperties: [VariableDeclSyntax],
  initializers: [InitializerDeclSyntax],
  userTypeForStorageName: [String : TypeSyntax]
) throws -> ClassDeclSyntax {
  func resolveStorageNameAndTypes(
    for extractedStorageNameAndTypes: [String : TypeSyntax?],
    with userTypeForStorageName: [String : TypeSyntax]
  ) throws -> [String : TypeSyntax] {
    var resolvedStorageNameAndTypes = [String : TypeSyntax]()
    for (storageName, typeOrNil) in extractedStorageNameAndTypes {
      let userTypeOrNil = userTypeForStorageName[storageName]
      let resolvedTypeOrNil = typeOrNil ?? userTypeOrNil
      guard let resolvedType = resolvedTypeOrNil else {
        throw StorageClassCreationError.noInferredTypeAndUserType(storageName: storageName)
      }
      resolvedStorageNameAndTypes[storageName] = resolvedType
    }
    return resolvedStorageNameAndTypes
  }
  
  let allStorageNamesAndTypes = Dictionary(
    uniqueKeysWithValues: storedProperties.flatMap(\.allIdentifiersAndTypes)
  )
  
  let resolvedStorageNameAndTypes = try resolveStorageNameAndTypes(
    for: allStorageNamesAndTypes,
    with: userTypeForStorageName
  )
  
  let needsCreateMemberwiseInitializer = initializers.reduce(true) { partial, initializer in
    partial && !initializer.isMemberwiseInitializer(storageNames: allStorageNamesAndTypes.keys)
  }
  
  let memberwiseInitializer: InitializerDeclSyntax?
  
  if needsCreateMemberwiseInitializer {
    memberwiseInitializer = makeStorageClassMemberwiseInitializerDecl(
      resolvedStorageNameAndTypes: resolvedStorageNameAndTypes
    )
  } else {
    memberwiseInitializer = nil
  }
  
  let copyInitializer = makeStorageClassCopyInitializer(
    storageClassName: className,
    storageNames: allStorageNamesAndTypes.keys
  )
  
  return ClassDeclSyntax { classDecl in
    classDecl.useIdentifier(.identifier(className))
    classDecl.useMembers(
      MemberDeclBlockSyntax { memberDeclBlock in
        for eachStoredProperty in storedProperties {
          memberDeclBlock.addMember(MemberDeclListItemSyntax { memberDeclListItem in
            memberDeclListItem.useDecl(DeclSyntax(eachStoredProperty))
          })
        }
        for eachInitializer in initializers {
          memberDeclBlock.addMember(MemberDeclListItemSyntax { memberDeclListItem in
            memberDeclListItem.useDecl(DeclSyntax(eachInitializer))
          })
        }
        if let memberwiseInitializer = memberwiseInitializer {
          memberDeclBlock.addMember(
            MemberDeclListItemSyntax { memberDeclListItem in
              memberDeclListItem.useDecl(DeclSyntax(memberwiseInitializer))
            }
          )
        }
        memberDeclBlock.addMember(
          MemberDeclListItemSyntax { memberDeclListItem in
            memberDeclListItem.useDecl(DeclSyntax(copyInitializer))
          }
        )
      }
    )
  }
}

/// Make variable like
///
/// ```
/// var foo: Bar {
///   _read {
///     yield storage.foo
///   }
///   _modify {
///     yield &storage.foo
///   }
///}
/// ```
///
/// from
///
/// ```
/// var foo: Bar
/// ```
///
private func makeStorageDispatchedVariableDecls(
  storedPropertyVariableDecl: VariableDeclSyntax,
  storageVariableName: String,
  storageUnificationFunctionName: String,
  resolvedStorageNameAndTypes: [String : TypeSyntax]
) -> [VariableDeclSyntax] {
  storedPropertyVariableDecl.bindings.map { binding -> VariableDeclSyntax in
    VariableDeclSyntax { variableDecl in
      let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)!
      let storageName = identifierPattern.identifier.text
      variableDecl.useLetOrVarKeyword(.var)
      if let attributes = storedPropertyVariableDecl.attributes {
        for each in attributes.storageDispatchedVariableAllowedAttributes {
          variableDecl.addAttribute(each)
        }
      }
      if let modifiers = storedPropertyVariableDecl.modifiers {
        for each in modifiers.storageDispatchedVariableAllowedModifiers {
          variableDecl.addModifier(each)
        }
      }
      variableDecl.addBinding(
        PatternBindingSyntax { patternBinding in
          patternBinding.usePattern(binding.pattern)
          patternBinding.useTypeAnnotation(
            TypeAnnotationSyntax { typeAnnotation in
              typeAnnotation.useType(resolvedStorageNameAndTypes[storageName]!)
            }
          )
          patternBinding.useAccessor(
            Syntax(
              AccessorBlockSyntax { accessorBlock in
                accessorBlock.useLeftBrace(.leftParen)
                accessorBlock.addAccessor(
                  AccessorDeclSyntax { accessor in
                    accessor.useAccessorKind(.contextualKeyword("_read"))
                    accessor.useBody(
                      CodeBlockSyntax { codeBlock in
                        codeBlock.useLeftBrace(.leftParen)
                        codeBlock.addStatement(
                          CodeBlockItemSyntax { codeBlockItem in
                            codeBlockItem.useItem(
                              Syntax(
                                YieldStmtSyntax { yieldStmt in
                                  yieldStmt.useYieldKeyword(.yield)
                                  yieldStmt.useYields(
                                    Syntax(
                                      MemberAccessExprSyntax { memberAccess in
                                        memberAccess.useBase(
                                          ExprSyntax(
                                            MemberAccessExprSyntax { memberAccess in
                                              memberAccess.useBase(
                                                ExprSyntax(
                                                  IdentifierExprSyntax { identifierExpr in
                                                    identifierExpr.useIdentifier(.`self`)
                                                  }
                                                )
                                              )
                                              memberAccess.useDot(.period)
                                              memberAccess.useName(.identifier(storageVariableName))
                                            }
                                          )
                                        )
                                        memberAccess.useDot(.period)
                                        memberAccess.useName(.identifier(storageName))
                                      }
                                    )
                                  )
                                }
                              )
                            )
                          }
                        )
                        codeBlock.useRightBrace(.rightParen)
                      }
                    )
                  }
                )
                accessorBlock.addAccessor(
                  AccessorDeclSyntax { accessor in
                    accessor.useAccessorKind(.contextualKeyword("_modify"))
                    accessor.useBody(
                      CodeBlockSyntax { codeBlock in
                        codeBlock.useLeftBrace(.leftParen)
                        codeBlock.addStatement(
                          CodeBlockItemSyntax { codeBlockItem in
                            codeBlockItem.useItem(
                              Syntax(
                                FunctionCallExprSyntax { funcCall in
                                  funcCall.useCalledExpression(
                                    ExprSyntax(
                                      MemberAccessExprSyntax { memberAccess in
                                        memberAccess.useBase(
                                          ExprSyntax(
                                            IdentifierExprSyntax { identifierExpr in
                                              identifierExpr.useIdentifier(.`self`)
                                            }
                                          )
                                        )
                                        memberAccess.useDot(.period)
                                        memberAccess.useName(.identifier(storageUnificationFunctionName))
                                      }
                                    )
                                  )
                                }
                              )
                            )
                            codeBlockItem.useItem(
                              Syntax(
                                YieldStmtSyntax { yieldStmt in
                                  yieldStmt.useYieldKeyword(.yield)
                                  yieldStmt.useYields(
                                    Syntax(
                                      InOutExprSyntax { inOutExpr in
                                        inOutExpr.useAmpersand(.prefixAmpersand)
                                        inOutExpr.useExpression(
                                          ExprSyntax(
                                            MemberAccessExprSyntax { memberAccess in
                                              memberAccess.useBase(
                                                ExprSyntax(
                                                  MemberAccessExprSyntax { memberAccess in
                                                    memberAccess.useBase(
                                                      ExprSyntax(
                                                        IdentifierExprSyntax { identifierExpr in
                                                          identifierExpr.useIdentifier(.`self`)
                                                        }
                                                      )
                                                    )
                                                    memberAccess.useDot(.period)
                                                    memberAccess.useName(.identifier(storageVariableName))
                                                  }
                                                )
                                              )
                                              memberAccess.useDot(.period)
                                              memberAccess.useName(.identifier(storageName))
                                            }
                                          )
                                        )
                                      }
                                    )
                                  )
                                }
                              )
                            )
                          }
                        )
                        codeBlock.useRightBrace(.rightParen)
                      }
                    )
                  }
                )
                accessorBlock.useRightBrace(.rightParen)
              }
            )
          )
        }
      )
    }
  }
}

private func makeStorageUnificationFunctionDecl(
  functionName: String,
  storageClassName: String,
  storageVariableName: String
) -> FunctionDeclSyntax {
  FunctionDeclSyntax { funcDecl in
    funcDecl.useFuncKeyword(.func)
    funcDecl.useIdentifier(.identifier(functionName))
    funcDecl.useSignature(FunctionSignatureSyntax({ _ in }))
    funcDecl.useBody(
      CodeBlockSyntax { codeBlock in
        codeBlock.useLeftBrace(.leftBrace)
        codeBlock.addStatement(
          CodeBlockItemSyntax { codeBlockItem in
            codeBlockItem.useItem(
              Syntax(
                /*
                 guard !isKnownUniquelyReferenced(&storage) else {
                   return
                 }
                 */
                GuardStmtSyntax { guardStmt in
                  guardStmt.useGuardKeyword(.guard)
                  guardStmt.addCondition(
                    ConditionElementSyntax { conditionElement in
                      conditionElement.useCondition(
                        Syntax(
                          PrefixOperatorExprSyntax { prefixOperatorExpr in
                            prefixOperatorExpr.useOperatorToken(.exclamationMark)
                            prefixOperatorExpr.usePostfixExpression(
                              ExprSyntax(
                                FunctionCallExprSyntax { funcCallExpr in
                                  funcCallExpr.useCalledExpression(
                                    ExprSyntax(
                                      IdentifierExprSyntax { identifierExpr in
                                        identifierExpr.useIdentifier(.identifier("isKnownUniquelyReferenced"))
                                      }
                                    )
                                  )
                                  funcCallExpr.useLeftParen(.leftParen)
                                  funcCallExpr.addArgument(
                                    TupleExprElementSyntax { tupleExprElet in
                                      tupleExprElet.useExpression(
                                        ExprSyntax(
                                          InOutExprSyntax { inoutExpr in
                                            inoutExpr.useAmpersand(.prefixAmpersand)
                                            inoutExpr.useExpression(
                                              ExprSyntax(
                                                IdentifierExprSyntax { identifierExpr in
                                                  identifierExpr.useIdentifier(.identifier(storageVariableName))
                                                }
                                              )
                                            )
                                          }
                                        )
                                      )
                                    }
                                  )
                                  funcCallExpr.useLeftParen(.rightParen)
                                }
                              )
                            )
                          }
                        )
                      )
                    }
                  )
                  guardStmt.useElseKeyword(.else)
                  guardStmt.useBody(
                    CodeBlockSyntax { codeBlock in
                      codeBlock.useLeftBrace(.leftParen)
                      codeBlock.addStatement(
                        CodeBlockItemSyntax { codeBlockItem in
                          codeBlockItem.useItem(
                            Syntax(
                              ReturnStmtSyntax { returnStmt in
                                returnStmt.useReturnKeyword(.return)
                              }
                            )
                          )
                        }
                      )
                      codeBlock.useRightBrace(.rightParen)
                    }
                  )
                }
              )
            )
            /*
             self.storage = Storage(storage)
             */
            codeBlockItem.useItem(
              Syntax(
                SequenceExprSyntax { sequenceExpr in
                  sequenceExpr.addElement(
                    ExprSyntax(
                      MemberAccessExprSyntax { memberAccess in
                        memberAccess.useBase(
                          ExprSyntax(
                            IdentifierExprSyntax { identifier in
                              identifier.useIdentifier(.`self`)
                            }
                          )
                        )
                        memberAccess.useDot(.period)
                        memberAccess.useName(.identifier(storageVariableName))
                      }
                    )
                  )
                  sequenceExpr.addElement(
                    ExprSyntax(
                      AssignmentExprSyntax { `assignment` in
                        `assignment`.useAssignToken(.equal)
                      }
                    )
                  )
                  sequenceExpr.addElement(
                    ExprSyntax(
                      FunctionCallExprSyntax { funcCallExpr in
                        funcCallExpr.useCalledExpression(
                          ExprSyntax(
                            IdentifierExprSyntax { identifierExpr in
                              identifierExpr.useIdentifier(.identifier(storageClassName))
                            }
                          )
                        )
                        funcCallExpr.useLeftParen(.leftParen)
                        funcCallExpr.addArgument(
                          TupleExprElementSyntax { tupleExprElet in
                            tupleExprElet.useExpression(
                              ExprSyntax(
                                IdentifierExprSyntax { identifierExpr in
                                  identifierExpr.useIdentifier(.identifier(storageVariableName))
                                }
                              )
                            )
                          }
                        )
                        funcCallExpr.useLeftParen(.rightParen)
                      }
                    )
                  )
                }
              )
            )
          }
        )
        codeBlock.useRightBrace(.rightBrace)
      }
    )
  }
}

private func makeStorageClassMemberwiseInitializerDecl(
  resolvedStorageNameAndTypes: [String : TypeSyntax]
) -> InitializerDeclSyntax {
  return InitializerDeclSyntax { initializer in
    initializer.useInitKeyword(.`init`)
    initializer.useParameters(
      ParameterClauseSyntax { parameters in
        parameters.useLeftParen(.leftParen)
        for (storageName, resolvedStorageType) in resolvedStorageNameAndTypes {
          parameters.addParameter(
            FunctionParameterSyntax { parameter in
              parameter.useFirstName(.identifier(storageName))
              parameter.useColon(.colon)
              parameter.useType(resolvedStorageType)
            }
          )
        }
        parameters.useRightParen(.rightParen)
      }
    )
    initializer.useBody(
      CodeBlockSyntax { codeBlock in
        codeBlock.useLeftBrace(.leftBrace)
        for (storageName, _) in resolvedStorageNameAndTypes {
          codeBlock.addStatement(
            CodeBlockItemSyntax { item in
              item.useItem(
                Syntax(
                  SequenceExprSyntax { sequenceExpr in
                    sequenceExpr.addElement(
                      ExprSyntax(
                        MemberAccessExprSyntax { memberAccess in
                          memberAccess.useBase(
                            ExprSyntax(
                              IdentifierExprSyntax { identifier in
                                identifier.useIdentifier(.`self`)
                              }
                            )
                          )
                          memberAccess.useDot(.period)
                          memberAccess.useName(.identifier(storageName))
                        }
                      )
                    )
                    sequenceExpr.addElement(
                      ExprSyntax(
                        AssignmentExprSyntax { `assignment` in
                          `assignment`.useAssignToken(.equal)
                        }
                      )
                    )
                    sequenceExpr.addElement(
                      ExprSyntax(
                        IdentifierExprSyntax { identifier in
                          identifier.useIdentifier(.identifier(storageName))
                        }
                      )
                    )
                  }
                )
              )
            }
          )
        }
        codeBlock.useRightBrace(.leftBrace)
      }
    )
  }
}

private func makeStorageClassCopyInitializer<StorageNames: Sequence>(storageClassName: String, storageNames: StorageNames) -> InitializerDeclSyntax where StorageNames.Element == String {
  return InitializerDeclSyntax { initializer in
    initializer.useInitKeyword(.`init`)
    initializer.useParameters(
      ParameterClauseSyntax { parameters in
        parameters.useLeftParen(.leftParen)
        parameters.addParameter(
          FunctionParameterSyntax { parameter in
            parameter.useFirstName(.wildcard)
            parameter.useSecondName(.identifier("storage"))
            parameter.useColon(.colon)
            parameter.useType(
              TypeSyntax(
                SimpleTypeIdentifierSyntax { simpleIdType in
                  simpleIdType.useName(.identifier(storageClassName))
                }
              )
            )
          }
        )
        parameters.useRightParen(.rightParen)
      }
    )
    initializer.useBody(
      CodeBlockSyntax { codeBlock in
        codeBlock.useLeftBrace(.leftBrace)
        for eachStorageName in storageNames {
          codeBlock.addStatement(
            CodeBlockItemSyntax { item in
              item.useItem(
                Syntax(
                  SequenceExprSyntax { sequenceExpr in
                    sequenceExpr.addElement(
                      ExprSyntax(
                        MemberAccessExprSyntax { memberAccess in
                          memberAccess.useBase(
                            ExprSyntax(
                              IdentifierExprSyntax { identifier in
                                identifier.useIdentifier(.`self`)
                              }
                            )
                          )
                          memberAccess.useDot(.period)
                          memberAccess.useName(.identifier(eachStorageName))
                        }
                      )
                    )
                    sequenceExpr.addElement(
                      ExprSyntax(
                        AssignmentExprSyntax { `assignment` in
                          `assignment`.useAssignToken(.equal)
                        }
                      )
                    )
                    sequenceExpr.addElement(
                      ExprSyntax(
                        MemberAccessExprSyntax { memberAccess in
                          memberAccess.useBase(
                            ExprSyntax(
                              IdentifierExprSyntax { identifier in
                                identifier.useIdentifier(.identifier("storage"))
                              }
                            )
                          )
                          memberAccess.useDot(.period)
                          memberAccess.useName(.identifier(eachStorageName))
                        }
                      )
                    )
                  }
                )
              )
            }
          )
        }
        codeBlock.useRightBrace(.leftBrace)
      }
    )
  }
}

extension VariableDeclSyntax {
  
  fileprivate var allIdentifiersAndTypes: [String : TypeSyntax?] {
    let allIdentifiersAndTypes = bindings
      .compactMap { binding -> (String, TypeSyntax?)? in
        guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
          return nil
        }
        
        let type = binding.typeAnnotation?.type
        
        return (identifierPattern.identifier.text, type)
      }
    return Dictionary(uniqueKeysWithValues: allIdentifiersAndTypes)
  }
  
}


extension InitializerDeclSyntax {
  
  func isMemberwiseInitializer<S: Sequence>(storageNames: S) -> Bool where S.Element == String {
    fatalError()
  }
  
}


extension AttributeListSyntax {
  
  fileprivate var storageDispatchedVariableAllowedAttributes: [Syntax] {
    filter { syntax in
      !syntax.is(CustomAttributeSyntax.self)
    }
  }
  
}



extension ModifierListSyntax {
  
  fileprivate var storageDispatchedVariableAllowedModifiers: [DeclModifierSyntax] {
    filter { syntax in
      [.public, .private, .internal, .fileprivate].contains(syntax.name)
    }
  }
  
}
