; inherits: html_tags

[
  "["
  "]"
] @punctuation.bracket

(interpolation) @punctuation.special

(interpolation
  (raw_text) @none)

(dynamic_directive_inner_value) @variable

(directive_name) @function.macro.vue

(directive_attribute
  (quoted_attribute_value ("\"" @punctuation.special))
)

; Accessing a component object's field
(":"
  .
  (directive_value) @variable.member)

; @click is like onclick for HTML
("@"
  .
  (directive_value) @function.method)

; Used in v-slot, declaring position the element should be put in
("#"
  .
  (directive_value) @variable.parameter)

(directive_attribute
  (quoted_attribute_value (attribute_value) @none))

(directive_attribute
  (quoted_attribute_value
    (attribute_value) @none))

[
  (directive_modifier)
] @field
