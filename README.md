# nim2c

This program creates a rest wrapper around shared libraries using the data.json file. It's bascially a code generator which iterates over the configuration specified in the data file. Let us look at a small example of how the json looke like.
```json
[{
    "library": "hello_nim", 
    "types": [{
        "name": "BufferObj",
        "signature": "data:cstring[decode],size:cint,fill:cint"
    }],
    "functions": [{
            "name": "hello_2",
            "returntype": "cint",
            "params": {
                "count": 2,
                "args": [{
                        "name": "bufOut",
                        "functype": "BufferObj",
                        "isCustom": "true",
                        "isPointer": "true",
                        "isOut": "true",
                        "decode": "false"
                    },
                    {
                        "name": "bufIn",
                        "functype": "BufferObj",
                        "isCustom": "true",
                        "isPointer": "true",
                        "isOut": "false",
                        "decode": "false"
                    }
                ]
            }
        }
    ]
}]
```
Let's decode the json now:
* Firstly we have an array of libraries.
* Then in each library we have the following data
    * library - The name of the library.
    * types - The custom types used in the library which consists of 
        *  name - The name of the custom type.
        *  signature - The nim signature of the custom type.
    * functions - The procedures present in the library and it consists of
        * name - The name of the procedure.
        * returntype - The return type of the procedure.
        * params - The parameters which the procedure accepts. It further consists of
            * name - The parameter name.
            * functype - The data type of the paramter.
            * isCustom - Is the parameter is of custom type of builtin type.
            * isPointer - Should the parameter be passed as pointer.
            * isOut - Is the parameter an out parameter (Should it be passed back to the user).
            * decode - Should the parameter be decoded from base64.
            
# Instructions
* Install the depndecies.
* Place the shared library in the same directory as source code.
* Modify data.json to suit your needs.
* Execute codeGen.nim.
* Execute the generated nimFile.
* Profit :)
* 
# Dependencies
https://github.com/flyx/NimYAML
