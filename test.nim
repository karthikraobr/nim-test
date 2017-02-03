import dynlib,macros,json,streams

proc sayHelloWorld: cstring {.importc, dynlib:"libfoo.dll", stdcall.}

proc greet(name: cstring): cstring {.importc, dynlib:"libfoo.dll", stdcall.}

macro typeDef(): untyped =
    var procptr = newNimNode(nnkProcTy).add(newNimNode(nnkFormalParams).add(ident("cstring"))).add(newNimNode(nnkPragma).add(ident("nimcall")))
    var finale = newPar(procptr)
    var temp = newStmtList(finale)
    echo temp.repr
    result = temp

proc main*() =
    echo "test 1 (fixed)"
    echo sayHelloWorld()
    echo greet("Foo")
    echo "-----"
    echo "test 2 (dynamic)"
    var lib = loadLib("libfoo.dll")
    var sayPtr = symAddr(lib, "sayHelloWorld")
    var greetPtr = symAddr(lib, "greet")
    #let small_json = """{"returnType": "cstring", "pragma": nimcall}"""    
    var say = cast[typeDef()](sayPtr)
    echo say()

when isMainModule:
    main()
