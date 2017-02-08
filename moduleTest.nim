import os,strutils,yaml.serialization, yaml.presenter,streams

type Arguments = object
    name:string
    functype:string


type Parameters = object
    count:string
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
    var res = " "
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
    source &= "proc loadLib[T](libraryName:string, functionName:string,args:string):T=\n"
    source &= getIndentation(1)&"case libraryName:\n"
    for library in finalRes:
        
        source &= getIndentation(2) & "of " & '"' & library.library & '"' & ":\n"
        source &= getIndentation(3) & "var lib" & library.library & " = loadLib(" & '"' & getLibName(library.library) & '"' & ")\n"
        source &= getIndentation(3) & "case functionName:\n"
        for fun in library.functions:
            source &= getIndentation(4) & "of "&'"'& fun.name & '"' & ":\n"
            source &= getIndentation(4) & "# Library name =" & library.library & "\t" & "Function name =" & fun.name&"\n"
            source &= getIndentation(5) & "type " & fun.name & " = " & fun.signature & "\n"
            source &= getIndentation(5) & "var ptr" & fun.name & " = symAddr(lib" & library.library & "," & '"' & fun.name & '"' & ")\n"
            source &= getIndentation(5) & "var exec" & fun.name & " = cast[" & fun.name & "](" & "ptr" & fun.name & ")\n"       
            source &= getIndentation(5) & "let argsCount = " &  fun.params.count & "\n" 
            if fun.params.count > 0:
                source &= getIndentation(5) & "result = exec"& fun.name & "()\n"
            else 
                source &= getIndentation(5) & "result = exec"& fun.name & "(args)\n"
        source &= getIndentation(4) & "else:result=nil\n\n"
    source &= getIndentation(2) & "else:result=nil\n\n"     
    
    
    
    source &= "when isMainModule:\n" 
    source &= getIndentation(2)& "echo(" & '"' & "Hello" & '"' & ")"
    write(file,source)