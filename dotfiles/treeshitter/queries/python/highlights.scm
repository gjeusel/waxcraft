;; From tree-sitter-python licensed under MIT License
; Copyright (c) 2016 Max Brunsfeld

; Variables
(identifier) @variable

; Reset highlighing in f-string interpolations
(interpolation) @none

; ; Identifier naming conventions
; ((identifier) @type
;  (#match? @type "^[A-Z]"))

((identifier) @constant
 (#match? @constant "^[A-Z][A-Z_0-9]*$"))

((identifier) @constant.builtin
 (#any-of? @constant.builtin
           ;; https://docs.python.org/3/library/constants.html
           "NotImplemented"
           "Ellipsis"
           "quit"
           "exit"
           "copyright"
           "credits"
           "license"
           "__name__"
           "__file__"
           "__module__"
           "__import__"
           "__doc__"
           "__dict__"
           "__package__"
           "__slots__"
))

((identifier) @function
 (#any-of? @function
              ;; https://docs.python.org/3/library/exceptions.html
              "BaseException" "Exception" "ArithmeticError" "BufferError" "LookupError" "AssertionError" "AttributeError"
              "EOFError" "FloatingPointError" "GeneratorExit" "ImportError" "ModuleNotFoundError" "IndexError" "KeyError"
              "KeyboardInterrupt" "MemoryError" "NameError" "NotImplementedError" "OSError" "OverflowError" "RecursionError"
              "ReferenceError" "RuntimeError" "StopIteration" "StopAsyncIteration" "SyntaxError" "IndentationError" "TabError"
              "SystemError" "SystemExit" "TypeError" "UnboundLocalError" "UnicodeError" "UnicodeEncodeError" "UnicodeDecodeError"
              "UnicodeTranslateError" "ValueError" "ZeroDivisionError" "EnvironmentError" "IOError" "WindowsError"
              "BlockingIOError" "ChildProcessError" "ConnectionError" "BrokenPipeError" "ConnectionAbortedError"
              "ConnectionRefusedError" "ConnectionResetError" "FileExistsError" "FileNotFoundError" "InterruptedError"
              "IsADirectoryError" "NotADirectoryError" "PermissionError" "ProcessLookupError" "TimeoutError" "Warning"
              "UserWarning" "DeprecationWarning" "PendingDeprecationWarning" "SyntaxWarning" "RuntimeWarning"
              "FutureWarning" "ImportWarning" "UnicodeWarning" "BytesWarning" "ResourceWarning"))

; Decorators
(decorator
  [
    (identifier) @constructor
    (attribute) @constructor
    (call (attribute) @constructor)
    (call (identifier) @constructor)
  ]
)

;; Builtin functions
(
  [
    (call (argument_list (identifier) @function.builtin))
    (pair value: (identifier) @function.builtin)
    (pair value:
      (subscript [
        value: (identifier)
        subscript: (identifier)
      ] @function.builtin)
    )
    (keyword_argument value: (identifier) @function.builtin)
    (call function: (identifier) @function.builtin)
  ]
 (any-of? @function.builtin
          "abs" "all" "any" "ascii" "bin" "bool" "breakpoint" "bytearray" "bytes" "callable" "chr" "classmethod"
          "compile" "complex" "delattr" "dict" "dir" "divmod" "enumerate" "eval" "exec" "filter" "float" "format"
          "frozenset" "getattr" "globals" "hasattr" "hash" "help" "hex" "id" "input" "int" "isinstance" "issubclass"
          "iter" "len" "list" "locals" "map" "max" "memoryview" "min" "next" "object" "oct" "open" "ord" "pow"
          "print" "property" "range" "repr" "reversed" "round" "set" "setattr" "slice" "sorted" "staticmethod" "str"
          "sum" "super" "tuple" "type" "vars" "zip" "__import__")
)

;; Function definitions

(function_definition
  name: (identifier) @function)

((call
  function: (identifier) @_isinstance
  arguments: (argument_list
    (_)
    (identifier) @type))
 (#eq? @_isinstance "isinstance"))

;; Normal parameters
(parameters
  (identifier) @parameter)
;; Lambda parameters
(lambda_parameters
  (identifier) @parameter)
(lambda_parameters
  (tuple_pattern
    (identifier) @parameter))
; Default parameters
(keyword_argument
  name: (identifier) @parameter)
; Naming parameters on call-site
(default_parameter
  name: (identifier) @parameter)
(typed_parameter
  (identifier) @parameter)
(typed_default_parameter
  (identifier) @parameter)
; Variadic parameters *args, **kwargs
(parameters
  (list_splat_pattern ; *args
    (identifier) @parameter))
(parameters
  (dictionary_splat_pattern ; **kwargs
    (identifier) @parameter))


;; Literals

(none) @constant.builtin
[(true) (false)] @boolean

(integer) @number
(float) @float

(comment) @comment
(string) @string
(escape_sequence) @string.escape

; Tokens

[
  "-"
  "-="
  ":="
  "!="
  "*"
  "**"
  "**="
  "*="
  "/"
  "//"
  "//="
  "/="
  "&"
  "&="
  "%"
  "%="
  "^"
  "^="
  "+"
  "+="
  "<"
  "<<"
  "<<="
  "<="
  "<>"
  "="
  "=="
  ">"
  ">="
  ">>"
  ">>="
  "|"
  "|="
  "~"
  "->"
] @operator

; Keywords
[
  "and"
  "in"
  "is"
  "not"
  "or"
  "del"
  "@"
] @keyword.operator

[
  "assert"
  "async"
  "await"
  "class"
  "def"
  "except"
  "exec"
  "finally"
  "global"
  "lambda"
  "nonlocal"
  "pass"
  "print"
  "raise"
  "return"
  "try"
  "with"
  "yield"
  "as"
] @keyword

["from" "import"] @include
(aliased_import "as" @include)

["if" "elif" "else"] @conditional

["for" "while" "break" "continue"] @repeat

["(" ")" "[" "]" "{" "}"] @punctuation.bracket

; (interpolation
;   "{" @punctuation.special
;   "}" @punctuation.special)

["," "." ":" (ellipsis)] @punctuation.delimiter


;; Type Hint
(type
  [
    (identifier) @type
    (subscript (identifier) @type)
    (subscript (subscript (identifier) @type))
  ]
)

(ellipsis) @punctuation.special

;; Class definitions
(class_definition
  name: (identifier) @type
)

(class_definition
  body: (block
    [
      (decorated_definition
        (function_definition (identifier) @method)
      )
      (function_definition name: (identifier) @method)
    ]
  )
)

; (class_definition
;   name: (identifier) @type
;   body: (block
;           (function_definition
;             name: (identifier) @method)))

; (class_definition
;   superclasses: (argument_list
;                   (identifier) @type))

((class_definition
  body: (block
          (expression_statement
            (assignment
              left: (identifier) @field))))
 (#vim-match? @field "^([A-Z])@!.*$"))

((class_definition
  body: (block
          (expression_statement
            (assignment
              left: (_ 
                     (identifier) @field)))))
 (#vim-match? @field "^([A-Z])@!.*$"))

((attribute
    attribute: (identifier) @field)
 (#vim-match? @field "^([A-Z])@!.*$"))


; First parameter of a method or decorated method is self or cls.
; ((class_definition
;   body: (block
;   [
;     (function_definition (parameters (identifier) @variable.builtin))
;     (decorated_definition (function_definition (parameters (identifier) @variable.builtin)))
;   ]
; ))
; (#any-of? @variable.builtin "cls" "self" "obj" "class"))

((identifier) @variable.builtin
 (#match? @variable.builtin "^(self|cls)$"))

;; Error
(ERROR) @error
