##{.compile: "logic.c".}
import dynlib
##proc addThreeIntegers(a, b, c: cint): cint {.importc.}
##proc addTwoIntegers(bla1,bla2: cint):cint{.importc.}
##proc returnString(str: cstring):cstring{.importc.}
proc factorial(): cuint {.stdcall, importc: "factorial", dynlib: "factorial.dll".}
proc getLibName(libraryName:string):string = 
    result = ""
    when defined(Windows):
        result = libraryName & ".dll"
    elif defined(Linux):
        result = libraryName & ".so"
    return result

when isMainModule:
  echo factorial()
  ##echo addThreeIntegers(8, 7, 9)
  ##echo addTwoIntegers(1,2)
  ##echo returnString("hello world")
  ##echo getLibName("libfactorial")
  #let libname = "./lib/" & getLibName("libfactorial")
  #echo libname
  var lib = dynlib.loadLib(getLibName("libfactorial"))
  
  if lib != nil:
      echo "Lib Loaded"
      var address = lib.symAddr("factorial")
      echo "The address of sayHi is ", cast[int](address)