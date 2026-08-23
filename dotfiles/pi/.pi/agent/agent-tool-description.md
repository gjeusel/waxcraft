Launch a new agent to handle complex, multi-step tasks autonomously. Each agent type has specific capabilities and tools available to it.

Available agent types and the tools they have access to:
{{typeList}}

Custom agents can be defined in .pi/agents/<name>.md (project) or {{agentDir}}/agents/<name>.md (global). Project agents override global agents, and a custom agent with the same name as a built-in overrides that built-in.

When using the Agent tool, specify `subagent_type` and a short 3-5 word `description`.

## Model selection

Use `openai-codex/gpt-5.6-luna` for almost every subagent. Pass it explicitly through the `model` argument unless the agent definition already pins it.

For a genuinely complex task that needs the strongest reasoning available in the current session, twin the currently active model instead: omit the `model` argument so the subagent inherits the parent's model. Complexity means architecture, subtle debugging, security analysis, or implementation requiring broad synthesis—not merely a long search.

## When not to use

If the target is already known, use a direct tool: `read` for a known path and the appropriate search tool for a specific symbol or string. Reserve agents for open-ended codebase searches, independent investigations, complex multi-step tasks, or work matching a specialized agent type.

Do not delegate your own understanding. Research findings can inform your next action, but you must synthesize them and give any implementation agent concrete file paths, relevant constraints, and the exact change to make.

## Usage notes

- Launch multiple independent agents in a single message so they run concurrently. If the user explicitly requests parallel execution, use multiple Agent tool calls in that same message.
- Agents run in the background by default. Do not poll or sleep while waiting; continue with other useful work.
- Use `run_in_background: false` only when the result gates your very next action and nothing else can usefully proceed.
- A background agent's result is unknown until its completion notification arrives. Never predict or fabricate it.
- Use `get_subagent_result` to retrieve the full result after completion.
- Use `steer_subagent` to redirect a running agent.
- Resume an existing agent with its ID or handle. A fresh Agent call has no memory of an earlier run.
- Clearly state whether the agent should only research or may modify files.
- If an agent type's description says it should be used proactively, prefer using it when its specialty applies.
- Use `thinking` deliberately; keep it low for routine searches and increase it only when reasoning complexity warrants the cost.
- Use `inherit_context` only when the child genuinely needs the parent conversation. Otherwise provide a self-contained prompt.
- Trust but verify. Check the actual files and test results after an agent modifies code; its summary is not proof of completion.{{isolationGuideline}}{{scheduleGuideline}}

## Writing the prompt

Brief the agent like a capable colleague joining the task without prior context:

- Explain the objective and why it matters.
- Include what is already known or ruled out.
- Name relevant files, symbols, constraints, and expected output.
- Give enough context for judgment rather than prescribing brittle search steps.
- For a lookup, provide the exact target. For an investigation, provide the question.
- State an output limit when a concise report is required.

Avoid terse prompts and phrases such as “based on your findings, fix it.” Research agents should report evidence; the main agent should understand that evidence before delegating a specific implementation.
