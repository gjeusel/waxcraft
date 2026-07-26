import { existsSync, readdirSync, readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

// Registers a slash command per discovered skill (Claude Code behavior that
// opencode lacks: skills are only model-invocable tools via the
// opencode-agent-skills plugin, never TUI commands).
//
// Same discovery order as opencode-agent-skills — first match per name wins:
const skillRoots = (projectDir) => [
  join(projectDir, ".opencode", "skills"),
  join(projectDir, ".claude", "skills"),
  join(homedir(), ".config", "opencode", "skills"),
  join(homedir(), ".claude", "skills"),
]

// Built-in TUI command names we must not shadow.
const BUILTINS = new Set([
  "init", "new", "share", "unshare", "help", "exit", "quit", "compact",
  "export", "editor", "models", "sessions", "themes", "agents", "commands",
  "details", "undo", "redo", "connect", "mcp",
])

function frontmatterDescription(skillFile) {
  const head = readFileSync(skillFile, "utf8").slice(0, 4096)
  const match = head.match(/^description:[ \t]*(.+)$/m)
  if (!match) return undefined
  let desc = match[1].trim()
  // YAML block scalar (">-", "|", ...) → take the first indented line instead
  if (/^[>|][+-]?$/.test(desc)) {
    const after = head.slice(match.index + match[0].length)
    desc = after.match(/^[ \t]+(.+)$/m)?.[1].trim() ?? ""
  }
  desc = desc.replace(/^["']|["']$/g, "")
  return desc.length > 80 ? desc.slice(0, 77) + "..." : desc || undefined
}

export const SkillCommands = async ({ directory }) => {
  return {
    config: async (config) => {
      config.command ??= {}
      for (const root of skillRoots(directory)) {
        if (!existsSync(root)) continue
        for (const entry of readdirSync(root, { withFileTypes: true })) {
          try {
            // no isDirectory() check: skills are often symlinked dirs (e.g.
            // ~/.claude/skills/* → ~/.agents/skills/*) and Dirent reports
            // those as symlinks; existsSync follows links either way
            const name = entry.name
            const skillFile = join(root, name, "SKILL.md")
            if (!existsSync(skillFile)) continue
            if (BUILTINS.has(name) || config.command[name]) continue
            config.command[name] = {
              description: frontmatterDescription(skillFile) ?? `${name} skill`,
              template: [
                `Load the skill named "${name}" and follow its instructions exactly.`,
                `Use the use_skill tool if available; otherwise read ${skillFile} and follow it.`,
                ``,
                `$ARGUMENTS`,
              ].join("\n"),
            }
          } catch (error) {
            console.error(`skill-commands: skipping ${entry.name}: ${error}`)
          }
        }
      }
    },
  }
}
