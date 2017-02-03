import macros

macro typeDef(): untyped =
    #var parameters: seq[NimNode]
    #parameters = @[]
    #parameters.add(ident("string"))
    #parameters.add(newIdentDefs(ident("a"), ident("string")))
    #var procedure = newProc(params=parameters,body=newEmptyNode() )
    #var temp = newStmtList(procedure)
    #echo temp.repr

    var procptr = newNimNode(nnkProcTy).add(newNimNode(nnkFormalParams).add(ident("int")).add(newIdentDefs(ident("x"),ident("int")))).add(newNimNode(nnkPragma).add(ident("nimcall")))
    var finale = newPar(procptr)
    var temp = newStmtList(finale)
    echo temp.repr
    result = temp

when isMainModule:
    type foo = typeDef()
    
    dumptree:
      (proc(): cstring {.nimcall.})