import os,strutils,yaml.serialization, yaml.presenter,streams

type Arguments = object
    name:string
    functype:string
    isPointer:bool
    isCustom:bool
    isOut:bool

type Parameters = object
    count:int
    args:seq[Arguments]

type Functions = object
    name:string
    returntype:string
    params:Parameters

type CustomType = object
    name:string
    signature:string

type Config = object
    types:seq[CustomType]
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
        res &= arg.name & ":"
        if arg.isPointer == true:
          res &= "ptr "
        res &= arg.functype
        i+=1
        if i>=1:
            res &= ","
    res &= "):T{.nimcall.})"
    result = res


proc getTypeConverterName(typeName:string ):string=
    case typeName:
        of "cstring":
            return "getStr"
        of "cint":
            return "getNum"
        else: discard

proc toString(str: seq[char]): string =
  result = newStringOfCap(len(str))
  for ch in str:
    add(result, ch)

proc getPadding(length:int):string=
    var str = newSeq[char]()
    for i in countup(0,length):
        str.add('0')
    return toString(str)


when isMainModule:
    var finalRes :seq[Config]
    var s = newFileStream("data.json")
    load(s, finalRes)
    s.close()
    echo(finalRes)
    var file = open("nimFile.nim",fmwrite)

    var source = "import dynlib,strutils,asynchttpserver,asyncdispatch,json,yaml.serialization\n\n"
    for library in finalRes:
        for customType in library.types:
            source &= "type " & customType.name & " = object\n"
            for member in split(customType.signature,','):
                source &= getIndentation(1) & member & "\n"
    
    source &= "proc toString(str: seq[char]): string =\n"
    source &= getIndentation(1) & "result = newStringOfCap(len(str))\n"
    source &= getIndentation(1)  & "for ch in str:\n"
    source &= getIndentation(2) & "add(result, ch)\n\n"

    source &= "proc getPadding(length:BiggestInt):string=\n"
    source &= getIndentation(1) & "var str = newSeq[char]()\n"
    source &= getIndentation(1) & "for i in countup(0,length-1):\n"
    source &= getIndentation(2) & "str.add('0')\n"
    source &= getIndentation(1) & "return toString(str)\n\n"

    source &= "proc loadLib[T](libraryName:string, functionName:string,args:string):JsonNode=\n"
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
            var temp = "var final = %*{"
            if fun.params.count > 0:
                source &= getIndentation(5) & "var jobj = parseJson(args)\n"
                var argumentString:string
                for i in countup(0,fun.params.count-1):
                    if fun.params.args[i].isCustom :
                        source &= getIndentation(5) & "var obj_" & intToStr(i) & " = jobj[" & intToStr(i) & "]\n"
                        source &= getIndentation(5) & "var arg_" & intToStr(i) & ":"& fun.params.args[i].functype & "\n"
                        for customType in library.types:
                            if customType.name == fun.params.args[i].functype:
                                for member in split(customType.signature,','):
                                    var mem = split(member,':')
                                    if mem[1] == "cstring" and fun.params.args[i].isOut:
                                        
                                        source &= getIndentation(5) & "var str_"& intToStr(i) & "= " & "getPadding("& "obj_" & intToStr(i) & "[" & '"' & "size" & '"' & "].getNum"&")" & "\n"
                                        source &= getIndentation(5) & "arg_" & intToStr(i) & "." & mem[0] & " = " & mem[1] & "(" & "str_"& intToStr(i) & ")\n"
                                    else :
                                        source &= getIndentation(5) & "arg_" & intToStr(i) & "." & mem[0] & " = " & mem[1] & "(obj_" & intToStr(i) & "[" & '"' & mem[0] & '"'& "]." & getTypeConverterName(mem[1]) & ")\n"
                                    if fun.params.args[i].isOut:
                                        temp &= '"' & mem[0] & '"' & " : " & "$" & "arg_" & intToStr(i) & "." & mem[0] & ","
                    else : 
                        source &= getIndentation(5) & "var arg_" & intToStr(i) & ":"& fun.params.args[i].functype & "\n"
                        if fun.params.args[i].functype == "cstring" and fun.params.args[i].isOut:
                            source &= getIndentation(5) & "var str_"& intToStr(i) & "= " & "getPadding(size)" & "\n"
                            source &= getIndentation(5) & "arg_" & intToStr(i) & " = " & "cstring" & "(" & "str_"& intToStr(i) & ")\n"
                        else:
                            source &= getIndentation(5) & "arg_" & intToStr(i) & " = " & fun.params.args[i].functype & "(jobj" & "[" & '"' & fun.params.args[i].name & '"'& "]." & getTypeConverterName(fun.params.args[i].functype) &  ")\n"
                        if fun.params.args[i].isOut:
                             temp &= '"' & fun.params.args[i].name & '"' & " : " & "$" & "arg_" & intToStr(i) & ","

                    if i == 0:
                      if fun.params.args[i].isPointer:
                        argumentString = "arg_" & intToStr(i) & ".addr"
                      else :
                        argumentString = "arg_" & intToStr(i)
                    elif i > 0:
                      if fun.params.args[i].isPointer:
                        argumentString &= ",arg_" & intToStr(i) & ".addr"
                      else :
                        argumentString &= ",arg_" & intToStr(i)
                source &= getIndentation(5) & "var res = "&"exec" & fun.name & "(" & argumentString & ")\n"
                if temp != "var final = %*{":
                    temp &= "}\n"
                    source &= getIndentation(5) & temp
                    source &= getIndentation(5) & "var j = %* {"& '"'& "result" & '"' & ": $res ,"& '"'& "out" & '"' & ": final"&"}\n"
                else :
                    source &= getIndentation(5) & "var res = "& "exec" & fun.name & "()\n"
                    source &= getIndentation(5) & "var j = %* {"& '"'& "result" & '"' & ": $res}\n"

            else :
                source &= getIndentation(5) & "var res = "& "exec" & fun.name & "()\n"
                source &= getIndentation(5) & "var j = %* {"& '"'& "result" & '"' & ": $res}\n"
            source &= getIndentation(5) & "return j \n"
        source &= getIndentation(4) & "else:discard\n"
    source &= getIndentation(2) & "else:discard\n\n"     

    source &= "proc getResult(libraryName:string,functionName:string,args:string):JsonNode =\n"
    source &= getIndentation(1) & "case libraryName:\n"
    for library in finalRes:
      source &= getIndentation(2) & "of " & '"'& library.library & '"' & ":\n"
      source &= getIndentation(3) & "case functionName:\n"
      for fun in library.functions:
          source &= getIndentation(4) & "of " & '"' & fun.name & '"' & ":\n"
          source &= getIndentation(5) & "var res = loadLib[" & fun.returntype & "](libraryName,functionName,args)\n"
          source &= getIndentation(5) &  "return res\n"
      source &= getIndentation(4) & "else : discard\n"
    source &= getIndentation(2) & "else : discard\n"
    

    source &= "var server = newAsyncHttpServer()\n\nproc handler(req: Request) {.async.} =\n" 
    source &= getIndentation(1)& "if req.url.path == "  & '"' & "/callLibFunction" & '"' & ":\n"
    source &= getIndentation(2)& "let requestBody = req.body\n"
    source &= getIndentation(2)& "var jobj = parseJson(req.body)\n"
    source &= getIndentation(2)& "var j = getResult(jobj[" & '"'& "libraryName" & '"'  & "].getStr,jobj["& '"'& "functionName" & '"'&"].getStr,$jobj["& '"'& "args" & '"'&"])\n"
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