import dynlib,strutils

type BufferObj = object
 data:cstring
 size:cint
 fill:cint

iterator countTo(n: int): int =
  var i = 0
  while i <= n:
    yield i
    inc i
proc main*() =
    var libhello_nim = loadLib("hello_nim.dll")
    type hello_2 = (proc (bufOut:ref BufferObj,bufIn:ref BufferObj,):cint{.nimcall.})
    var ptrhello_2 = symAddr(libhello_nim,"hello_2")
    var exechello_2 = cast[hello_2](ptrhello_2)
    var arg_0: ref BufferObj = new(BufferObj)
    var str1 = "           "
    #GC_ref(str1)
    arg_0.data = cstring(str1)
    arg_0.size = cint(11)
    arg_0.fill = cint(11)
    var arg_1:ref BufferObj = new(BufferObj)
    var str2 = "Hello World"
    #GC_ref(str2)
    arg_1.data = cstring(str2)
    arg_1.size = cint(11)
    arg_1.fill = cint(11)
    var res = exechello_2(arg_0,arg_1)
    for i in countTo(11):
        if $arg_0.data[i] == $arg_1.data[i]:
            echo $arg_0.data[i] , $arg_1.data[i]
    echo str1
    #echo $arg_1
    #echo arg_0,"\n"
    #echo res
    #GCunref(str1)
    #GCunref(str2)
    unloadlib(libhello_nim)



when isMainModule:
    for i in countTo(200):
        echo "The count is ",i
        main()
