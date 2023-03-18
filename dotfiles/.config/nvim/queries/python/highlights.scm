; Reset highlighting in f-string interpolations
(interpolation) @none

((identifier) @constant
 (#lua-match? @constant "^[A-Z][A-Z_0-9]*$"))

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

; Decorators
(decorator
  [
    ; (call function: (attribute) @function.macro)
    (identifier) @function.macro
    (attribute) @function.macro
    (call (attribute) @function.macro)
    (call (identifier) @function.macro)
  ]
)

; Builtin functions
((call
  function: (identifier) @function.builtin)
 (#any-of? @function.builtin
          "abs" "all" "any" "ascii" "bin" "bool" "breakpoint" "bytearray" "bytes" "callable" "chr" "classmethod"
          "compile" "complex" "delattr" "dict" "dir" "divmod" "enumerate" "eval" "exec" "filter" "float" "format"
          "frozenset" "getattr" "globals" "hasattr" "hash" "help" "hex" "id" "input" "int" "isinstance" "issubclass"
          "iter" "len" "list" "locals" "map" "max" "memoryview" "min" "next" "object" "oct" "open" "ord" "pow"
          "print" "property" "range" "repr" "reversed" "round" "set" "setattr" "slice" "sorted" "staticmethod" "str"
          "sum" "super" "tuple" "type" "vars" "zip" "__import__"))


;; Function definitions

(function_definition
  name: (identifier) @definition.function
)

(call
  function: (identifier) @function.call)

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

(comment) @comment @spell
(string) @string @spell
(escape_sequence) @string.escape

((module . (comment) @preproc)
  (#match? @preproc "^#!/"))

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
  "not in"
  "is not"
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

["if" "elif" "else" "match" "case"] @conditional

["for" "while" "break" "continue"] @repeat

["(" ")" "[" "]" "{" "}"] @punctuation.bracket

["," "." ":"] @punctuation.delimiter

(ellipsis) @punctuation.special


;; Type Hint
(type
  [
    (identifier) @type
    (_ (identifier) @type)
    (_ (_ (identifier) @type))
    (_ (_ (_ (identifier) @type)))
    (_ (_ (_ (_ (identifier) @type))))
    (_ (_ (_ (_ (_ (identifier) @type)))))
    (_ (_ (_ (_ (_ (_ (identifier) @type))))))
    (_ (_ (_ (_ (_ (_ (_ (identifier) @type)))))))
  ]
)

;; Class definitions
(class_definition
  name: (identifier) @type
)

(class_definition
  body: (block
    [
      (decorated_definition
        (function_definition (identifier) @definition.method)
      )
      (function_definition name: (identifier) @definition.method)
    ]
  )
)

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

((class_definition
  (block
    (function_definition
      name: (identifier) @constructor)))
 (#any-of? @constructor "__new__" "__init__"))

((attribute
    attribute: (identifier) @field)
 (#vim-match? @field "^([A-Z])@!.*$"))


((identifier) @variable.builtin
 (#match? @variable.builtin "^(self|cls)$"))

; Exceptions
(raise_statement
  [
    (call (identifier) @exception)
  ]
)


;; Error
(ERROR) @error
