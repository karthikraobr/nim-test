import dynlib 
var function1 = (proc ():cstring{.nimcall.})
var function2 = (proc (int,int):cstring{.nimcall.})
var lib = dynlib.loadLib(getLibName(foo.dll))
if lib != nil:
	 echo(libName)