//
//  MakeStorageClass.swift
//  COWRewriter
//
//  Created by WeZZard on 6/6/22.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import Collections

func makeStorageClass(
  structDecl: StructDeclSyntax,
  className: String,
  resolvedStorageNameAndTypes: OrderedDictionary<String, TypeSyntax>
) -> ClassDeclSyntax {
  let storedVariables = structDecl.members.members.storedVariables
  let initializers = structDecl.members.members.initializers
  
  let needsCreateMemberwiseInitializer = initializers.reduce(true) { partial, initializer in
    partial && !initializer.isMemberwiseInitializer(storageNames: resolvedStorageNameAndTypes.keys)
  }
  
  let memberwiseInitializer: InitializerDeclSyntax?
  
  if needsCreateMemberwiseInitializer {
    memberwiseInitializer = makeStorageClassMemberwiseInitializerDecl(
      resolvedStorageNameAndTypes: resolvedStorageNameAndTypes
    ).withLeadingTrivia(.newlines(2))
  } else {
    memberwiseInitializer = nil
  }
  
  let copyInitializer = makeStorageClassCopyInitializer(
    storageClassName: className,
    storageNames: resolvedStorageNameAndTypes.keys
  ).withLeadingTrivia(.newlines(2))
  
  return ClassDeclSyntax { classDecl in
    classDecl.addModifier(
      DeclModifierSyntax { declModifierSyntax in
        declModifierSyntax.useName(.private)
      }
    )
    classDecl.useClassOrActorKeyword(.class)
    classDecl.useIdentifier(.identifier(className))
    classDecl.useMembers(
      MemberDeclBlockSyntax { memberDeclBlock in
        memberDeclBlock.useLeftBrace(.leftBrace)
        for eachStoredProperty in storedVariables {
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
        memberDeclBlock.useRightBrace(.rightBrace)
      }
    )
  }
}

private func makeStorageClassMemberwiseInitializerDecl(
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
        codeBlock.useRightBrace(.rightBrace)
      }
    )
  }
}

private func makeStorageClassCopyInitializer<StorageNames: Sequence>(
  storageClassName: String,
  storageNames: StorageNames
) -> InitializerDeclSyntax where StorageNames.Element == String {
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
        codeBlock.useRightBrace(.rightBrace)
      }
    )
  }
}
