import os,strutils,yaml.serialization, yaml.presenter,streams

type Functions = object
    name:string
    signature:string

type Config = object
    library:string
    functions:seq[Functions]

proc getLibName(libraryName:string):string = 
    result = ""
    when defined(Windows):
        result = libraryName & ".dll"
    elif defined(Linux):
        result = libraryName & ".so"
    return result

when isMainModule:
    var finalRes :seq[Config]
#var i = open("input.nim")
    var s = newFileStream("data.json")
    load(s, finalRes)
    s.close()
    echo(finalRes)
    var file = open("nimFile.nim",fmwrite)
    var source = "import dynlib \n"
    for library in finalRes:
        for item in library.functions:
            source &= "var " & item.name & " = " & item.signature & "\n"
        var libName = getLibName(library.library)
        source &= "var lib = dynlib.loadLib(getLibName(" & libName & "))\n"
        source &= "if lib != nil:\n\t echo(libName)"
    write(file,source)
#echo (i.getFileHandle())