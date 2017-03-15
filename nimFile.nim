import dynlib,strutils,asynchttpserver,asyncdispatch,json,yaml.serialization

type BufferObj = object
 data:cstring
 size:cint
 fill:cint
proc toString(str: seq[char]): string =
 result = newStringOfCap(len(str))
 for ch in str:
  add(result, ch)

proc getPadding(length:BiggestInt):string=
 var str = newSeq[char]()
 for i in countup(0,length-1):
  str.add('0')
 return toString(str)

proc loadLib[T](libraryName:string, functionName:string,args:string):JsonNode=
 case libraryName:
  of "hello_nim":
    var libhello_nim = loadLib("hello_nim.dll")
    case functionName:
        of "hello_1":
        # Library name =hello_nim	Function name =hello_1
                type hello_1 = (proc (out1:cstring,outlen:cint,in1:cstring,inlen:cint,):T{.nimcall.})
                var ptrhello_1 = symAddr(libhello_nim,"hello_1")
                var exechello_1 = cast[hello_1](ptrhello_1)
                var jobj = parseJson(args)
                var arg_0:cstring
                var str_0= getPadding(jobj["outlen"].getNum)
                arg_0 = cstring(str_0)
                var arg_1:cint
                arg_1 = cint(jobj["outlen"].getNum)
                var arg_2:cstring
                arg_2 = cstring(jobj["in1"].getStr)
                var arg_3:cint
                arg_3 = cint(jobj["inlen"].getNum)
                var res = exechello_1(arg_0,arg_1,arg_2,arg_3)
                var final = %*{"out1" : $arg_0,}
                var j = %* {"result": $res ,"out": final}
                return j 
        of "hello_2":
        # Library name =hello_nim	Function name =hello_2
                type hello_2 = (proc (bufOut:ptr BufferObj,bufIn:ptr BufferObj,):T{.nimcall.})
                var ptrhello_2 = symAddr(libhello_nim,"hello_2")
                var exechello_2 = cast[hello_2](ptrhello_2)
                var jobj = parseJson(args)
                var obj_0 = jobj[0]
                var arg_0:BufferObj
                var str_0= getPadding(obj_0["size"].getNum)
                arg_0.data = cstring(str_0)
                arg_0.size = cint(obj_0["size"].getNum)
                arg_0.fill = cint(obj_0["fill"].getNum)
                var obj_1 = jobj[1]
                var arg_1:BufferObj
                arg_1.data = cstring(obj_1["data"].getStr)
                arg_1.size = cint(obj_1["size"].getNum)
                arg_1.fill = cint(obj_1["fill"].getNum)
                var res = exechello_2(arg_0.addr,arg_1.addr)
                var final = %*{"data" : $arg_0.data,"size" : $arg_0.size,"fill" : $arg_0.fill,}
                var j = %* {"result": $res ,"out": final}
                return j 
        else:discard
  else:discard

proc getResult(libraryName:string,functionName:string,args:string):JsonNode =
 case libraryName:
  of "hello_nim":
    case functionName:
        of "hello_1":
                var res = loadLib[cint](libraryName,functionName,args)
                return res
        of "hello_2":
                var res = loadLib[cint](libraryName,functionName,args)
                return res
        else : discard
  else : discard
var server = newAsyncHttpServer()

proc handler(req: Request) {.async.} =
 if req.url.path == "/callLibFunction":
  let requestBody = req.body
  var jobj = parseJson(req.body)
  var j = getResult(jobj["libraryName"].getStr,jobj["functionName"].getStr,$jobj["args"])
  if j!=nil:
    j = %* j
    let headers = newHttpHeaders([("Content-Type","application/json")])
    await req.respond(Http200,$j , headers)
  else:
    await req.respond(Http404, "Not Found")
 else:
  await req.respond(Http404, "Not Found")
waitFor server.serve(Port(8080), handler)