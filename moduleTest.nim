import os,strutils,yaml.serialization, yaml.presenter,streams

type Arguments = object
    name:string
    functype:string


type Parameters = object
    count:int
    args:seq[Arguments]
    returntype:string

type Functions = object
    name:string
    signature:string
    params:Parameters

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

proc getIndentation(count:int):string=
    var res = "    "
    var i=1
    while(i<count):
        res &= res
        i=i+1
    result=res
when isMainModule:
    var finalRes :seq[Config]
    var s = newFileStream("data.json")
    load(s, finalRes)
    s.close()
    echo(finalRes)
    var file = open("nimFile.nim",fmwrite)
    var source = "import dynlib \n\n"
    source &= "when isMainModule:\n\n" 
    for library in finalRes:
        var funArr=newSeq[string](library.functions.len)
        source &= "#Function pointers for library" & library.library & "\n"
        for item in library.functions:
            source &= getIndentation(1) & "type " & item.name & " = " & item.signature & "\n"
            funArr.add(item.name)
        echo(funArr)
        source &= "\n# Library name =" & library.library&"\n"
        source &= getIndentation(1) & "var lib" & library.library & " = dynlib.loadLib(" & '"' & getLibName(library.library) & '"' & ")\n"
        source &= getIndentation(1) & "if lib" & library.library & " != nil:\n\n"
        for fun in funArr:
            if(fun!=nil):
                source &= "# Library name =" & library.library & "\t" & "Function name =" & fun&"\n"
                source &= getIndentation(2) & "var ptr" & fun & " = symAddr(lib" & library.library & "," & '"' & fun & '"' & ")\n"
                source &= getIndentation(2) & "var exec" & fun & " = cast[" & fun & "](" & "ptr" & fun & ")\n\n"      
    write(file,source)