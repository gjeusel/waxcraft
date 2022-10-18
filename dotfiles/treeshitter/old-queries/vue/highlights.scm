[
  ; (component)
  ; (template_element)
  ;; (end_tag)
  ;; (start_tag)
  (tag_name)
] @tag

; Directive Attributes
(directive_attribute
  (quoted_attribute_value) @text
)
(directive_attribute [":"] @comment)
[
  (directive_modifier)
  (directive_name)
  (directive_argument)
] @symbol



; Normal Attribute
(attribute
  (quoted_attribute_value) @string
)
(attribute
  (attribute_name) @annotation
)

(erroneous_end_tag_name) @error

; (attribute_name) @none
; (attribute_value) @string
; (quoted_attribute_value) @string

(comment) @comment

(text) @none
;; (element) @string

;; (interpolation) @punctuation.special
(interpolation
  (raw_text) @none)

["{{" "}}" "="] @operator

[
 "<"
 ">"
 "</"
 "/>"
 ] @tag

