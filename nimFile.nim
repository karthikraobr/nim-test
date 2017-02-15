import dynlib,strutils,asynchttpserver,asyncdispatch,json,yaml.serialization

type LibRequest=object
 libraryName:string
 functionName:string
 args:seq[string]

proc loadLib[T](libraryName:string, functionName:string,args:seq[string]):T=
 case libraryName:
  of "libfoo":
    var liblibfoo = loadLib("libfoo.dll")
    case functionName:
        of "sayHelloWorld":
        # Library name =libfoo	Function name =sayHelloWorld
                type sayHelloWorld = (proc ():cstring{.nimcall.})
                var ptrsayHelloWorld = symAddr(liblibfoo,"sayHelloWorld")
                var execsayHelloWorld = cast[sayHelloWorld](ptrsayHelloWorld)
                result = execsayHelloWorld()
        of "greet":
        # Library name =libfoo	Function name =greet
                type greet = (proc (name: cstring):cstring{.nimcall.})
                var ptrgreet = symAddr(liblibfoo,"greet")
                var execgreet = cast[greet](ptrgreet)
                var args_1 = cast[string](args[0])
                result = execgreet(args_1)
        else:result=nil

  of "libfoo1":
    var liblibfoo1 = loadLib("libfoo1.dll")
    case functionName:
        of "sayHelloWorld1":
        # Library name =libfoo1	Function name =sayHelloWorld1
                type sayHelloWorld1 = (proc ():cstring{.nimcall.})
                var ptrsayHelloWorld1 = symAddr(liblibfoo1,"sayHelloWorld1")
                var execsayHelloWorld1 = cast[sayHelloWorld1](ptrsayHelloWorld1)
                result = execsayHelloWorld1()
        of "greet1":
        # Library name =libfoo1	Function name =greet1
                type greet1 = (proc (name: cstring):cstring{.nimcall.})
                var ptrgreet1 = symAddr(liblibfoo1,"greet1")
                var execgreet1 = cast[greet1](ptrgreet1)
                var args_1 = cast[string](args[0])
                result = execgreet1(args_1)
        else:result=nil

  else:result=nil

var server = newAsyncHttpServer()
proc handler(req: Request) {.async.} =
 if req.url.path == "/callLibFunction":
  let requestBody = req.body
  var finalRes :LibRequest
  load(requestBody, finalRes)
  var res = loadLib[cstring](finalRes.libraryName,finalRes.functionName,finalRes.args)
  var j = %* {"result" : $res}
  let headers = newHttpHeaders([("Content-Type","application/json")])
  await req.respond(Http200,$j , headers)
 else:
  await req.respond(Http404, "Not Found")
waitFor server.serve(Port(8080), handler)