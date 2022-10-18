; Regex
((call
  function: (attribute
    object: (identifier) @_re)
  arguments: (argument_list (string) @regex))
 (#eq? @_re "re")
 (#match? @regex "^r.*"))

; String interpolation
(string
  (interpolation [
    (attribute)
    (identifier)
    (call)
  ] @python
))
