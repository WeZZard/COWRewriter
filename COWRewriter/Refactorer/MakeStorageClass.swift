//
//  MakeStorageClass.swift
//  COWRewriter
//
//  Created by WeZZard on 6/6/22.
//

import SwiftSyntax
import SwiftSyntaxBuilder

func makeStorageClass(
  structDecl: StructDeclSyntax,
  className: String,
  resolvedStorageNameAndTypes: [String : TypeSyntax]
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
    )
  } else {
    memberwiseInitializer = nil
  }
  
  let copyInitializer = makeStorageClassCopyInitializer(
    storageClassName: className,
    storageNames: resolvedStorageNameAndTypes.keys
  )
  
  return ClassDeclSyntax { classDecl in
    classDecl.useIdentifier(.identifier(className))
    classDecl.useMembers(
      MemberDeclBlockSyntax { memberDeclBlock in
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
        codeBlock.useRightBrace(.leftBrace)
      }
    )
  }
}