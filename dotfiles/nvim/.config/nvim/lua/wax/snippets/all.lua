local ls = require("luasnip")

return {
  ls.parser.parse_snippet("$file$", "$TM_FILENAME"),
  ls.parser.parse_snippet("$uuid$", '"$UUID"'),
  ls.parser.parse_snippet("$filepath$", "$TM_FILEPATH"),
  ls.parser.parse_snippet("$date$", os.date("%Y-%m-%d")),
  ls.parser.parse_snippet("$time$", os.date("%H:%M")),
  ls.parser.parse_snippet("$datetime$", os.date("%Y-%m-%dT%H:%M:%S")),
}
