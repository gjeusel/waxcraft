; Make slidev fails on example:
; (fenced_code_block
;   (info_string) @language
;   (code_fence_content) @content)

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

; html
(fenced_code_block
  ((info_string) @_lang
    (#match? @_lang "html"))
  (code_fence_content) @html
)


((html_block) @html)
((html_tag) @html)
