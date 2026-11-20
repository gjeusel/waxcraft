The task is fired: the agent below now owns it. Do not work on it in this session.

Reply with exactly the shape below, with nothing before its first line and nothing after its last
section. Copy the first four lines as they are, replace each `<...>`, keep the glyphs and the order,
and use no emoji.

The fence below only delimits the template here. Do not copy it: write the message as plain
Markdown, with no surrounding code fence, and start every line at column 0, without indentation.

```text
⎇ !{{mrIid}}  {{mrState}}  {{mrUrl}}
◇ #{{issueIid}}  {{issueTitle}}  {{issueUrl}}
▸ Rex {{rexSession}} › {{branch}}  ·  {{models}}
{{mergeLine}}{{setupLine}}

Brief
- <one bullet per thing the agent will do>

Not covered
- <what stays with the user, and the action it takes>
```

- Brief: at most five bullets of one line each, as `<topic>: <what changes>`. It restates the `task`
  you passed, not the conversation: no recap of the problem, its cause, or how it was found.
- Not covered: only what the user must do or decide themselves because the agent will not. Leave the
  section out when it would be empty.

Session of the agent: {{sessionFile}}
