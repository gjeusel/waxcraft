Delegate a scoped task to an agent with its own context and tools.

Available agent types:
{{typeList}}

Specify `subagent_type` and a short 3-5 word `description`.

## Choosing and briefing an agent

Use direct tools for known paths or specific lookups. Agents are useful for open-ended searches, independent investigations, and delegated multi-step work.

Give the agent an objective, relevant context, constraints, and acceptance criteria. Include useful paths and symbols when known, and clearly state whether it may modify files. Let it investigate implementation details; evaluate its findings before deciding the next step.

Prefer the agent's model and thinking defaults unless the task warrants an override.

## Execution

- Launch independent agents together so they can run concurrently.
- Agents run in the background by default. Continue useful work rather than polling or sleeping. Use `run_in_background: false` when the result gates your next action and no independent work remains.
- Wait for completion before drawing conclusions; retrieve the full result with `get_subagent_result`.
- Use `steer_subagent` to redirect a running agent. Resume a completed agent by ID or handle when continuing its task; a fresh call has no memory of earlier runs.
- Use `inherit_context` when the child needs the parent conversation; otherwise provide a self-contained brief.
- Verify actual changes and relevant test results before reporting implementation complete.{{isolationGuideline}}{{scheduleGuideline}}
