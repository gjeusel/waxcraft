(fenced_code_block
  (info_string) @language
  (code_fence_content) @content)

; bash
(fenced_code_block
  ((info_string) @_lang
    (#match? @_lang "(sh|bash)"))
  (code_fence_content) @bash
)

; python
(fenced_code_block
  ((info_string) @_lang
    (#match? @_lang "python"))
  (code_fence_content) @bash
)


((html_block) @html)
((html_tag) @html)
