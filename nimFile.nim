import dynlib 

when isMainModule:

#Function pointers for librarylibfoo
    type sayHelloWorld = (proc ():cstring{.nimcall.})
    type greet = (proc (name: cstring):cstring{.nimcall.})

# Library name =libfoo
    var liblibfoo = dynlib.loadLib("libfoo.dll")
    if liblibfoo != nil:

# Library name =libfoo	Function name =sayHelloWorld
        var ptrsayHelloWorld = symAddr(liblibfoo,"sayHelloWorld")
        var execsayHelloWorld = cast[sayHelloWorld](ptrsayHelloWorld)

# Library name =libfoo	Function name =greet
        var ptrgreet = symAddr(liblibfoo,"greet")
        var execgreet = cast[greet](ptrgreet)

#Function pointers for librarylibfoo1
    type sayHelloWorld1 = (proc ():cstring{.nimcall.})
    type greet1 = (proc (name: cstring):cstring{.nimcall.})

# Library name =libfoo1
    var liblibfoo1 = dynlib.loadLib("libfoo1.dll")
    if liblibfoo1 != nil:

# Library name =libfoo1	Function name =sayHelloWorld1
        var ptrsayHelloWorld1 = symAddr(liblibfoo1,"sayHelloWorld1")
        var execsayHelloWorld1 = cast[sayHelloWorld1](ptrsayHelloWorld1)

# Library name =libfoo1	Function name =greet1
        var ptrgreet1 = symAddr(liblibfoo1,"greet1")
        var execgreet1 = cast[greet1](ptrgreet1)

