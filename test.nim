import dynlib,macros,json,streams,os,strutils,tables

proc sayHelloWorld: cstring {.importc, dynlib:"libfoo.dll", stdcall.}

proc greet(name: cstring): cstring {.importc, dynlib:"libfoo.dll", stdcall.}

macro returnType():untyped=
    let inputString = slurp("data.cfg")
    var source = ""
    for line in inputString.splitLines:
        if line.len < 1: continue
        var chunks = split(line, ',')
        if chunks.len != 2:
            error("Input needs comma split values, got: " & line)
        source &= chunks[1]
    result=parseStmt(source)

proc main*() =
    echo "test 1 (fixed)"
    echo sayHelloWorld()
    echo greet("Foo")
    echo "-----"
    echo "test 2 (dynamic)"
    var lib = loadLib("libfoo.dll")
    var sayPtr = symAddr(lib, "sayHelloWorld")
    #var greetPtr = symAddr(lib, "greet")
    type t = returnType()
    var say = cast[t](sayPtr)
    echo say()

when isMainModule:
    main()
