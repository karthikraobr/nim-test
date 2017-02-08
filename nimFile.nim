import dynlib,os 

proc loadLib[T](libraryName:string, functionName:string,args:string):T=
 case libraryName:
  of "libfoo":
    var liblibfoo = loadLib("libfoo.dll")
    case functionName:
        of "sayHelloWorld":
        # Library name =libfoo	Function name =sayHelloWorld
                type sayHelloWorld = (proc ():cstring{.nimcall.})
                var ptrsayHelloWorld = symAddr(liblibfoo,"sayHelloWorld")
                var execsayHelloWorld = cast[sayHelloWorld](ptrsayHelloWorld)
                let argsCount = 0
                result = execsayHelloWorld()
        of "greet":
        # Library name =libfoo	Function name =greet
                type greet = (proc (name: cstring):cstring{.nimcall.})
                var ptrgreet = symAddr(liblibfoo,"greet")
                var execgreet = cast[greet](ptrgreet)
                let argsCount = 1
                result = execgreet(args)
        else:result=nil

  of "libfoo1":
    var liblibfoo1 = loadLib("libfoo1.dll")
    case functionName:
        of "sayHelloWorld1":
        # Library name =libfoo1	Function name =sayHelloWorld1
                type sayHelloWorld1 = (proc ():cstring{.nimcall.})
                var ptrsayHelloWorld1 = symAddr(liblibfoo1,"sayHelloWorld1")
                var execsayHelloWorld1 = cast[sayHelloWorld1](ptrsayHelloWorld1)
                let argsCount = 0
                result = execsayHelloWorld1()
        of "greet1":
        # Library name =libfoo1	Function name =greet1
                type greet1 = (proc (name: cstring):cstring{.nimcall.})
                var ptrgreet1 = symAddr(liblibfoo1,"greet1")
                var execgreet1 = cast[greet1](ptrgreet1)
                let argsCount = 1
                result = execgreet1(args)
        else:result=nil

  else:result=nil

when isMainModule:
  let programName = paramStr(1)
  echo(loadLib[cstring]("libfoo","greet",programName))