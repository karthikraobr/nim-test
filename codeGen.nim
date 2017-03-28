import os,strutils,yaml.serialization, yaml.presenter,streams

type Arguments = object
    name:string
    functype:string
    isPointer:bool
    isCustom:bool
    isOut:bool
    decode:bool

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

#This procedure checks the OS type and appends returns the appropriate library type
proc getLibName(libraryName:string):string = 
    result = ""
    when defined(Windows):
        result = libraryName & ".dll"
    elif defined(Linux):
        result = libraryName & ".so"
    return result

#This procedure returns spaces used to indent code.
proc getIndentation(count:int):string=
    var res = " "
    var i=1
    while(i<count):
        res &= res
        i=i+1
    result=res

#This procedure creates the function pointer based on the arguments passed to it.
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

#This procedure gets the type converter based on the data type
proc getTypeConverterName(typeName:string ):string=
    case typeName:
        of "cstring":
            return "getStr"
        of "cint":
            return "getNum"
        else: discard

when isMainModule:
    # Deserialize the data.json
    var finalRes :seq[Config]
    var s = newFileStream("data.json")
    load(s, finalRes)
    s.close()
    #Open the file with write access. If file is not present, it will be created.
    var file = open("nimFile.nim",fmwrite)
    var source = "import dynlib,strutils,asynchttpserver,asyncdispatch,json,yaml.serialization,base64\n\n"
    for library in finalRes:
        #Create all the custom types.
        for customType in library.types:
            source &= "type " & customType.name & " = object\n"
            for member in split(customType.signature,','):
                #This check was added to suuport decoding of base64 strings.
                #If a field in a custom type needs to be decoded, then it would have to be specified within the []
                #Eg. "signature":"data:cstring[decode],size:cint,fill:cint"
                if member.contains('['):
                    source &= getIndentation(1) & member.split('[')[0] & "\n"
                else:
                    source &= getIndentation(1) & member & "\n"
    #Creates a toString procedure.
    #It basically converts a  seq to characters to a string.
    source &= "proc toString(str: seq[char]): string =\n"
    source &= getIndentation(1) & "result = newStringOfCap(len(str))\n"
    source &= getIndentation(1)  & "for ch in str:\n"
    source &= getIndentation(2) & "add(result, ch)\n\n"

    #Create getPadding procedure.
    #Creates a string of "length" length with all '0' characters
    source &= "proc getPadding(length:BiggestInt):string=\n"
    source &= getIndentation(1) & "var str = newSeq[char]()\n"
    source &= getIndentation(1) & "for i in countup(0,length-1):\n"
    source &= getIndentation(2) & "str.add('0')\n"
    source &= getIndentation(1) & "return toString(str)\n\n"

    source &= "proc loadLib[T](libraryName:string, functionName:string,args:string):JsonNode=\n"
    source &= getIndentation(1)&"case libraryName:\n"
    #Iterate over all the libraries in the json.
    for library in finalRes:
        #Create a switch case of the libraries.
        source &= getIndentation(2) & "of " & '"' & library.library & '"' & ":\n"
        #Load the library
        source &= getIndentation(3) & "var lib" & library.library & " = loadLib(" & '"' & getLibName(library.library) & '"' & ")\n"
        #Create a switch case of all the functions in a library.
        source &= getIndentation(3) & "case functionName:\n"
        for fun in library.functions:
            source &= getIndentation(4) & "of "&'"'& fun.name & '"' & ":\n"
            source &= getIndentation(4) & "# Library name =" & library.library & "\t" & "Function name =" & fun.name&"\n"
            #Create the function pointer type.
            source &= getIndentation(5) & "type " & fun.name & " = " & getFunctionPointer(fun.params.args) & "\n"
            #Get the reference of the function.
            source &= getIndentation(5) & "var ptr" & fun.name & " = symAddr(lib" & library.library & "," & '"' & fun.name & '"' & ")\n"
            #Cast the reference to the function pointer we created earlier.
            source &= getIndentation(5) & "var exec" & fun.name & " = cast[" & fun.name & "](" & "ptr" & fun.name & ")\n"
            #Create a string to store the out parameter json, which needs to be returned to the User.
            var temp = "var final = %*{"
            if fun.params.count > 0:
                #Handle the json from the client.
                source &= getIndentation(5) & "var jobj = parseJson(args)\n"
                var argumentString:string
                for i in countup(0,fun.params.count-1):
                    #If the parameter to the function is not a builtin type.
                    if fun.params.args[i].isCustom :
                        #Get the first argument
                        source &= getIndentation(5) & "var obj_" & intToStr(i) & " = jobj[" & intToStr(i) & "]\n"
                        source &= getIndentation(5) & "var arg_" & intToStr(i) & ":"& fun.params.args[i].functype & "\n"
                        for customType in library.types:
                            #Check aginst the signature of the custom type.
                            if customType.name == fun.params.args[i].functype:
                                for member in split(customType.signature,','):
                                    var mem = split(member,':')
                                    var decode = false
                                    if mem[1].contains('['):
                                        mem[1] = mem[1].split('[')[0]
                                        decode = true
                                    #Check if the parameter is an out parameter.
                                    #This is because out parameters have to be treated differently in our case.
                                    #We create an empty string with '0' using the getPadding procedure we created earlier, so that we have memory allocated and initialized to it.
                                    if mem[1] == "cstring" and fun.params.args[i].isOut:
                                        source &= getIndentation(5) & "var str_"& intToStr(i) & "= " & "getPadding("& "obj_" & intToStr(i) & "[" & '"' & "size" & '"' & "].getNum"&")" & "\n"
                                        #Incase the string has to be decoded.
                                        if decode:
                                            source &= getIndentation(5) & "arg_" & intToStr(i) & "." & mem[0] & " = " & mem[1] & "(decode(" & "str_"& intToStr(i) & "))\n"
                                        else:
                                            source &= getIndentation(5) & "arg_" & intToStr(i) & "." & mem[0] & " = " & mem[1] & "(" & "str_"& intToStr(i) & ")\n"
                                    else :
                                        if decode:
                                            source &= getIndentation(5) & "arg_" & intToStr(i) & "." & mem[0] & " = " & mem[1] & "(decode(obj_" & intToStr(i) & "[" & '"' & mem[0] & '"'& "]." & getTypeConverterName(mem[1]) & "))\n"
                                        else:
                                            source &= getIndentation(5) & "arg_" & intToStr(i) & "." & mem[0] & " = " & mem[1] & "(obj_" & intToStr(i) & "[" & '"' & mem[0] & '"'& "]." & getTypeConverterName(mem[1]) & ")\n"
                                    #If it is an out parameter append the result to the temp string we created earlier.
                                    if fun.params.args[i].isOut:
                                        temp &= '"' & mem[0] & '"' & " : " & "$" & "arg_" & intToStr(i) & "." & mem[0] & ","
                    #If the parameter is of builtin type
                    else : 
                        source &= getIndentation(5) & "var arg_" & intToStr(i) & ":"& fun.params.args[i].functype & "\n"
                        #Handle out parameter which a string (Discussed earlier see line 147).
                        if fun.params.args[i].functype == "cstring" and fun.params.args[i].isOut:
                            source &= getIndentation(5) & "var str_"& intToStr(i) & "= " & "getPadding(jobj[" & '"' & "size" & '"' & "].getNum)" & "\n"
                            if fun.params.args[i].decode:
                                source &= getIndentation(5) & "arg_" & intToStr(i) & " = " & "cstring" & "(decode(" & "str_"& intToStr(i) & "))\n"
                            else:
                                source &= getIndentation(5) & "arg_" & intToStr(i) & " = " & "cstring" & "(" & "str_"& intToStr(i) & ")\n"
                        else:
                            if fun.params.args[i].decode:
                                     source &= getIndentation(5) & "arg_" & intToStr(i) & " = " & fun.params.args[i].functype & "(decode(jobj" & "[" & '"' & fun.params.args[i].name & '"'& "]." & getTypeConverterName(fun.params.args[i].functype) &  "))\n"
                            else:
                                source &= getIndentation(5) & "arg_" & intToStr(i) & " = " & fun.params.args[i].functype & "(jobj" & "[" & '"' & fun.params.args[i].name & '"'& "]." & getTypeConverterName(fun.params.args[i].functype) &  ")\n"
                           
                        if fun.params.args[i].isOut:
                             temp &= '"' & fun.params.args[i].name & '"' & " : " & "$" & "arg_" & intToStr(i) & ","
                    
                    #Handling pointers.
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
                #Creating the final json result.
                if temp != "var final = %*{":
                    temp &= "}\n"
                    source &= getIndentation(5) & temp
                    source &= getIndentation(5) & "var j = %* {"& '"'& "result" & '"' & ": $res ,"& '"'& "out" & '"' & ": final"&"}\n"
                else :
                    source &= getIndentation(5) & "var res = "& "exec" & fun.name & "()\n"
                    source &= getIndentation(5) & "var j = %* {"& '"'& "result" & '"' & ": $res}\n"
            #If procedure has no parameters.            
            else :
                source &= getIndentation(5) & "var res = "& "exec" & fun.name & "()\n"
                source &= getIndentation(5) & "var j = %* {"& '"'& "result" & '"' & ": $res}\n"
            #Return the result
            source &= getIndentation(5) & "return j \n"
        source &= getIndentation(4) & "else:discard\n"
    source &= getIndentation(2) & "else:discard\n\n"     

    #The below procedure is used to get the result from the shared library.
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
    

    #Handles HTTP request and response
    source &= "var server = newAsyncHttpServer()\n\nproc handler(req: Request) {.async.} =\n" 
    source &= getIndentation(1)& "if req.url.path == "  & '"' & "/callLibFunction" & '"' & ":\n"
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