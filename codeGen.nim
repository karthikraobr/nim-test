import os,strutils,yaml.serialization, yaml.presenter,streams

type Arguments = object
    name:string
    functype:string

type Parameters = object
    count:int
    args:seq[Arguments]

type Functions = object
    name:string
    returntype:string
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

proc getFunctionPointer(args:seq[Arguments]):string=
    var res = "(proc ("
    var i = 0
    for arg in args:
        res &= arg.name & ":" & arg.functype
        i+=1
        if i>1:
            res &= ","
    res &= "):T{.nimcall.})"
    result = res
    
proc getTypeConverterName(typeName:string,argIndex:int ):string=
    case typeName:
        of "bool":
            return "parseBool(args[" & intToStr(argIndex-1) & "])"
        of "int":
            return "parseInt(args[" & intToStr(argIndex-1) & "])"
        of "float":
            return "parseFloat(args[" & intToStr(argIndex-1) & "])"
        of "cint":
            return "cint(parseInt(args[" & intToStr(argIndex-1) & "]))"
        of "cfloat":
            return "cfloat(parseFloat(args[" & intToStr(argIndex-1) & "]))"
        else: return typeName & "(args[" & intToStr(argIndex-1) & "])"

when isMainModule:
    var finalRes :seq[Config]
    var s = newFileStream("data.json")
    load(s, finalRes)
    s.close()
    echo(finalRes)
    var file = open("nimFile.nim",fmwrite)

    var source = "import dynlib,strutils,asynchttpserver,asyncdispatch,json,yaml.serialization\n\n"
    source &= "type LibRequest=object\n"
    source &= getIndentation(1) & "libraryName:string\n"
    source &= getIndentation(1) & "functionName:string\n"
    source &= getIndentation(1) & "args:seq[string]\n\n"

    source &= "proc loadLib[T](libraryName:string, functionName:string,args:seq[string]):T=\n"
    source &= getIndentation(1)&"case libraryName:\n"
    for library in finalRes:
        source &= getIndentation(2) & "of " & '"' & library.library & '"' & ":\n"
        source &= getIndentation(3) & "var lib" & library.library & " = loadLib(" & '"' & getLibName(library.library) & '"' & ")\n"
        source &= getIndentation(3) & "case functionName:\n"
        for fun in library.functions:
            source &= getIndentation(4) & "of "&'"'& fun.name & '"' & ":\n"
            source &= getIndentation(4) & "# Library name =" & library.library & "\t" & "Function name =" & fun.name&"\n"
            source &= getIndentation(5) & "type " & fun.name & " = " & getFunctionPointer(fun.params.args) & "\n"
            source &= getIndentation(5) & "var ptr" & fun.name & " = symAddr(lib" & library.library & "," & '"' & fun.name & '"' & ")\n"
            source &= getIndentation(5) & "var exec" & fun.name & " = cast[" & fun.name & "](" & "ptr" & fun.name & ")\n"       
            if fun.params.count > 0:
                var argumentString:string
                for i in countup(1,fun.params.count):
                    source &= getIndentation(5) & "var args_" & intToStr(i) & " =" & getTypeConverterName(fun.params.args[i-1].functype,i) & "\n"
                    if i == 1:
                      argumentString = "args_" & intToStr(i)
                    elif i > 1:
                      argumentString &= ",args_" & intToStr(i)
                source &= getIndentation(5) & "return exec"& fun.name & "(" & argumentString & ")\n"
            else :
                source &= getIndentation(5) & "return exec"& fun.name & "()\n"
        source &= getIndentation(4) & "else:discard\n"
    source &= getIndentation(2) & "else:discard\n\n"     

    source &= "proc getResult(request:LibRequest):JsonNode =\n"
    source &= getIndentation(1) & "var j:JsonNode\n"
    source &= getIndentation(1) & "case request.libraryName:\n"
    for library in finalRes:
      source &= getIndentation(2) & "of " & '"'& library.library & '"' & ":\n"
      source &= getIndentation(3) & "case request.functionName:\n"
      for fun in library.functions:
          source &= getIndentation(4) & "of " & '"' & fun.name & '"' & ":\n"
          source &= getIndentation(5) & "var res = loadLib[" & fun.returntype & "](request.libraryName,request.functionName,request.args)\n"
          source &= getIndentation(5) &  "j = %* {"&'"'& "result"&'"' & ": $res}\n"
      source &= getIndentation(4) & "else : discard\n"
    source &= getIndentation(2) & "else : discard\n"
    source &=  getIndentation(1) & "result = j\n\n"
    

    source &= "var server = newAsyncHttpServer()\nproc handler(req: Request) {.async.} =\n\n" 
    source &= getIndentation(1)& "if req.url.path == "  & '"' & "/callLibFunction" & '"' & ":\n"
    source &= getIndentation(2)& "let requestBody = req.body\n"
    source &= getIndentation(2)& "var finalRes :LibRequest\n"
    source &= getIndentation(2)& "load(requestBody, finalRes)\n"
    source &= getIndentation(2)& "var j = getResult(finalRes)\n"
    source &= getIndentation(2)& "if j!=nil:\n"
    source &= getIndentation(3)& "j = %* j\n"
    source &= getIndentation(3)& "let headers = newHttpHeaders([("&'"'& "Content-Type"&'"'&","&'"' & "application/json"&'"'&")])\n"
    source &= getIndentation(3)& "await req.respond(Http200,$j , headers)\n"
    source &= getIndentation(2)& "else:\n"
    source &= getIndentation(3)& "await req.respond(Http404, " & '"' & "Not Found" & '"'&")\n"
    source &= getIndentation(1)& "else:\n"
    source &= getIndentation(2)& "await req.respond(Http404, " & '"' & "Not Found" & '"'&")\n"
    source &= "waitFor server.serve(Port(8080), handler)"
    write(file,source)