import dynlib,os

#proc sayHello: cstring {.importc, dynlib:"hello.dll", stdcall.}

#proc greet(name: cstring): cstring {.importc, dynlib:"libfoo.dll", stdcall.}

proc main*() =
    echo getCurrentDir()
    var liblibfoo = loadLib("hello_nim.dll")
    if liblibfoo != nil:
        echo "Loading Successful"
    else:
        echo "Failed"
    
    #echo sayHello()
    

when isMainModule:
    main()
