//
//  MakeCowStruct.swift
//  COWRewriter
//
//  Created by WeZZard on 6/6/22.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import Collections

func makeCowStruct(
  originalStructDecl: StructDeclSyntax,
  storageClass: ClassDeclSyntax,
  storageVariableName: String,
  storageUniquificationFunctionName: String,
  resolvedStorageNameAndTypes: OrderedDictionary<String, TypeSyntax>
) -> StructDeclSyntax {
  originalStructDecl.withMembers(
    MemberDeclBlockSyntax { memberDeclBlock in
      memberDeclBlock.useLeftBrace(.leftBrace)
      // class Storage { ... }
      memberDeclBlock.addMember(
        MemberDeclListItemSyntax { item in
          item.useDecl(DeclSyntax(storageClass))
        }
      )
      // var storage: Storage
      memberDeclBlock.addMember(
        MemberDeclListItemSyntax { item in
          item.useDecl(
            DeclSyntax(
              VariableDeclSyntax { variableDecl in
                variableDecl.addModifier(
                  DeclModifierSyntax { declModifier in
                    declModifier.useName(.private)
                  }
                )
                variableDecl.useLetOrVarKeyword(.var)
                variableDecl.addBinding(
                  PatternBindingSyntax { patternBinding in
                    patternBinding.usePattern(
                      PatternSyntax(
                        IdentifierPatternSyntax { identifierPattern in
                          identifierPattern.useIdentifier(.identifier(storageVariableName))
                        }
                      )
                    )
                    patternBinding.useTypeAnnotation(
                      TypeAnnotationSyntax { typeAnnotation in
                        typeAnnotation.useColon(.colon)
                        typeAnnotation.useType(
                          TypeSyntax(
                            SimpleTypeIdentifierSyntax { simpleTypeId in
                              simpleTypeId.useName(.identifier(storageClass.identifier.text))
                            }
                          )
                        )
                      }
                    )
                  }
                )
              }.withLeadingTrivia(.carriageReturnLineFeeds(2))
            )
          )
        }
      )
      // func makeUniqueStorageIfNeeded
      memberDeclBlock.addMember(
        MemberDeclListItemSyntax { item in
          item.useDecl(
            DeclSyntax(
              makeStorageUniquificationFunctionDecl(
                functionName: storageUniquificationFunctionName,
                storageClassName: storageClass.identifier.text,
                storageVariableName: storageVariableName
              ).withLeadingTrivia(.carriageReturnLineFeeds(2))
            )
          )
        }
      )
      // var foo: Bar {
      //   _read {
      //     ...
      //   }
      //   _modify {
      //     ...
      //   }
      // }
      for eachStoredVariable in originalStructDecl.members.members.storedVariables {
        let dispatchedVariableDecls = makeStorageDispatchedVariableDecls(
          storedPropertyVariableDecl: eachStoredVariable,
          storageVariableName: storageVariableName,
          storageUniquificationFunctionName: storageUniquificationFunctionName,
          resolvedStorageNameAndTypes: resolvedStorageNameAndTypes
        )
        for dispatchedVariableDecl in dispatchedVariableDecls {
          memberDeclBlock.addMember(
            MemberDeclListItemSyntax { item in
              item.useDecl(
                DeclSyntax(
                  dispatchedVariableDecl
                    .withLeadingTrivia(.carriageReturnLineFeeds(2))
                )
              )
            }
          )
        }
      }
      if originalStructDecl.members.members.initializers.isEmpty {
        memberDeclBlock.addMember(
          MemberDeclListItemSyntax { item in
            item.useDecl(
              DeclSyntax(
                makeStructMemberwiseInitializerDecl(
                  storageClassName: storageClass.identifier.text,
                  storageVariableName: storageVariableName,
                  resolvedStorageNameAndTypes: resolvedStorageNameAndTypes
                ).withLeadingTrivia(.carriageReturnLineFeeds(1))
              )
            )
          }
        )
      } else {
        for eachInitializer in originalStructDecl.members.members.initializers {
          memberDeclBlock.addMember(
            MemberDeclListItemSyntax { item in
              item.useDecl(
                DeclSyntax(
                  makeStructDispatchedInitializerDecl(
                    originalInitializer: eachInitializer,
                    storageClassName: storageClass.identifier.text,
                    storageVariableName: storageVariableName)
                )
              )
            }
          )
        }
      }
      for eachMember in originalStructDecl.members.members {
        if eachMember.decl.as(VariableDeclSyntax.self)?.isStored == true {
          continue
        }
        if eachMember.decl.is(InitializerDeclSyntax.self) {
          continue
        }
        memberDeclBlock.addMember(eachMember)
      }
      memberDeclBlock.useRightBrace(.rightBrace)
    }
  )
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
  storageUniquificationFunctionName: String,
  resolvedStorageNameAndTypes: OrderedDictionary<String, TypeSyntax>
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
              typeAnnotation.useColon(.colon)
              typeAnnotation.useType(resolvedStorageNameAndTypes[storageName]!)
            }
          )
          patternBinding.useAccessor(
            Syntax(
              AccessorBlockSyntax { accessorBlock in
                accessorBlock.useLeftBrace(.leftBrace)
                accessorBlock.addAccessor(
                  AccessorDeclSyntax { accessor in
                    accessor.useAccessorKind(.contextualKeyword("_read"))
                    accessor.useBody(
                      CodeBlockSyntax { codeBlock in
                        codeBlock.useLeftBrace(.leftBrace)
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
                        codeBlock.useRightBrace(.rightBrace)
                      }
                    )
                  }
                )
                accessorBlock.addAccessor(
                  AccessorDeclSyntax { accessor in
                    accessor.useAccessorKind(.contextualKeyword("_modify"))
                    accessor.useBody(
                      CodeBlockSyntax { codeBlock in
                        codeBlock.useLeftBrace(.leftBrace)
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
                                        memberAccess.useName(.identifier(storageUniquificationFunctionName))
                                      }
                                    )
                                  )
                                  funcCall.useLeftParen(.leftParen)
                                  funcCall.useRightParen(.rightParen)
                                }
                              )
                            )
                          }
                        )
                        codeBlock.addStatement(
                          CodeBlockItemSyntax { codeBlockItem in
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
                        codeBlock.useRightBrace(.rightBrace)
                      }
                    )
                  }
                )
                accessorBlock.useRightBrace(.rightBrace)
              }
            )
          )
        }
      )
    }
  }
}

private func makeStorageUniquificationFunctionDecl(
  functionName: String,
  storageClassName: String,
  storageVariableName: String
) -> FunctionDeclSyntax {
  FunctionDeclSyntax { funcDecl in
    funcDecl.useFuncKeyword(.func)
    funcDecl.addModifier(
      DeclModifierSyntax { declModifierSyntax in
        declModifierSyntax.useName(.private)
      }
    )
    funcDecl.addModifier(
      DeclModifierSyntax { declModifierSyntax in
        declModifierSyntax.useName(.contextualKeyword("mutating"))
      }
    )
    funcDecl.useIdentifier(.identifier(functionName))
    funcDecl.useSignature(
      FunctionSignatureSyntax { functionSignature in
        functionSignature.useInput(
          ParameterClauseSyntax { parameterClause in
            parameterClause.useLeftParen(.leftParen)
            parameterClause.useRightParen(.rightParen)
          }
        )
      }
    )
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
                                  funcCallExpr.useRightParen(.rightParen)
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
                      codeBlock.useLeftBrace(.leftBrace)
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
                      codeBlock.useRightBrace(.rightBrace)
                    }
                  )
                }
              )
            )
          }
        )
        /*
         self.storage = Storage(storage)
         */
        codeBlock.addStatement(
          CodeBlockItemSyntax { codeBlockItem in
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
                        funcCallExpr.useRightParen(.rightParen)
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

private func makeStructMemberwiseInitializerDecl(
  storageClassName: String,
  storageVariableName: String,
  resolvedStorageNameAndTypes: OrderedDictionary<String, TypeSyntax>
) -> InitializerDeclSyntax {
  return InitializerDeclSyntax { initializer in
    initializer.useInitKeyword(.`init`)
    initializer.useParameters(
      ParameterClauseSyntax { parameters in
        parameters.useLeftParen(.leftParen)
        for (index, (storageName, resolvedStorageType)) in resolvedStorageNameAndTypes.enumerated() {
          parameters.addParameter(
            FunctionParameterSyntax { parameter in
              parameter.useFirstName(.identifier(storageName))
              parameter.useColon(.colon)
              parameter.useType(resolvedStorageType)
              if index + 1 < resolvedStorageNameAndTypes.count {
                parameter.useTrailingComma(.comma)
              }
            }
          )
        }
        parameters.useRightParen(.rightParen)
      }
    )
    initializer.useBody(
      CodeBlockSyntax { codeBlock in
        codeBlock.useLeftBrace(.leftBrace)
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
                      FunctionCallExprSyntax { funcCall in
                        funcCall.useCalledExpression(
                          ExprSyntax(
                            IdentifierExprSyntax { identifier in
                              identifier.useIdentifier(.identifier(storageClassName))
                            }
                          )
                        )
                        funcCall.useLeftParen(.leftParen)
                        for (index, (storageName, _)) in resolvedStorageNameAndTypes.enumerated() {
                          funcCall.addArgument(
                            TupleExprElementSyntax { tupleExprElet in
                              tupleExprElet.useLabel(.identifier(storageName))
                              tupleExprElet.useColon(.colon)
                              tupleExprElet.useExpression(
                                ExprSyntax(
                                  IdentifierExprSyntax { identifierExpr in
                                    identifierExpr.useIdentifier(.identifier(storageName))
                                  }
                                )
                              )
                              if index + 1 < resolvedStorageNameAndTypes.count {
                                tupleExprElet.useTrailingComma(.comma)
                              }
                            }
                          )
                        }
                        funcCall.useRightParen(.rightParen)
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

private func makeStructDispatchedInitializerDecl(
  originalInitializer: InitializerDeclSyntax,
  storageClassName: String,
  storageVariableName: String
) -> InitializerDeclSyntax {
  return originalInitializer.withBody(
    CodeBlockSyntax { codeBlock in
      codeBlock.useLeftBrace(.leftBrace)
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
                    FunctionCallExprSyntax { funcCall in
                      funcCall.useCalledExpression(
                        ExprSyntax(
                          IdentifierExprSyntax { identifier in
                            identifier.useIdentifier(.identifier(storageClassName))
                          }
                        )
                      )
                      funcCall.useLeftParen(.leftParen)
                      for (index, parameter) in originalInitializer.parameters.parameterList.enumerated() {
                        funcCall.addArgument(
                          TupleExprElementSyntax { tupleExprElet in
                            tupleExprElet.useLabel(parameter.firstName!)
                            tupleExprElet.useColon(.colon)
                            tupleExprElet.useExpression(
                              ExprSyntax(
                                IdentifierExprSyntax { identifierExpr in
                                  identifierExpr.useIdentifier((parameter.firstName ?? parameter.secondName)!)
                                }
                              )
                            )
                            if index + 1 < originalInitializer.parameters.parameterList.count {
                              tupleExprElet.useTrailingComma(.comma)
                            }
                          }
                        )
                      }
                      funcCall.useRightParen(.rightParen)
                    }
                  )
                )
              }.withLeadingTrivia(.carriageReturnLineFeeds(1))
                .withTrailingTrivia(.carriageReturnLineFeeds(1))
            )
          )
        }
      )
      codeBlock.useRightBrace(.rightBrace)
    }
  )
}

// MARK: - Utilities


extension InitializerDeclSyntax {
  
  func isMemberwiseInitializer<S: Sequence>(storageNames: S) -> Bool where S.Element == String {
    let parameterNames = parameters.parameterList.compactMap { parameter -> String? in
      guard let name = (parameter.secondName ?? parameter.firstName) else {
        return nil
      }
      
      guard case let .identifier(text) = name.tokenKind else {
        return nil
      }
      
      return text
    }
    return Set(parameterNames) == Set(storageNames)
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
