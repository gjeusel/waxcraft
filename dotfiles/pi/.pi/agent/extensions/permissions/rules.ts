export interface PermissionsConfig {
  permissions?: {
    allow?: string[];
    deny?: string[];
  };
}

export interface ParsedRule {
  tool: string;
  pattern: RegExp;
  original: string;
}

export function globToRegex(glob: string): RegExp {
  const escaped = glob.replace(/([.+?^${}()|[\]\\])/g, '\\$1').replace(/\*/g, '.*');
  return new RegExp(`^${escaped}$`);
}

export function parseRule(rule: string): ParsedRule | null {
  const match = rule.match(/^(\w+)\((.+)\)$/);
  if (!match) return null;
  const [, tool, glob] = match;
  return {
    tool: tool.toLowerCase(),
    pattern: globToRegex(glob),
    original: rule,
  };
}

export function parseRules(rules: string[]): ParsedRule[] {
  return rules.map(parseRule).filter((r): r is ParsedRule => r !== null);
}

// Map pi tool names to permission tool names
export function getToolKey(toolName: string): string {
  switch (toolName) {
    case 'bash':
    case 'write':
    case 'edit':
    case 'read':
      return toolName;
    default:
      return toolName;
  }
}

// Extract the matchable string from tool input
export function getMatchTarget(toolName: string, input: Record<string, unknown>): string | null {
  switch (toolName) {
    case 'bash':
      return (input.command as string)?.trim() ?? null;
    case 'write':
    case 'edit':
    case 'read':
      return (input.path as string) ?? null;
    default:
      return null;
  }
}

export interface EvalResult {
  blocked: boolean;
  reason?: string;
}

/**
 * Evaluate whether a tool call should be blocked.
 * - Deny rules are checked first (deny always wins)
 * - If allow rules exist for the tool, the call must match at least one
 * - No rules = no restrictions
 */
export function evaluate(
  toolName: string,
  input: Record<string, unknown>,
  allowRules: ParsedRule[],
  denyRules: ParsedRule[],
): EvalResult {
  const toolKey = getToolKey(toolName);
  const target = getMatchTarget(toolName, input);
  if (!target) return { blocked: false };

  // Deny rules first — deny always wins
  for (const rule of denyRules) {
    if (rule.tool === toolKey && rule.pattern.test(target)) {
      return {
        blocked: true,
        reason: `Blocked by deny rule: ${rule.original}\nCommand: ${target}`,
      };
    }
  }

  // If allow rules exist for this tool, must match at least one
  const toolAllowRules = allowRules.filter((r) => r.tool === toolKey);
  if (toolAllowRules.length > 0) {
    const allowed = toolAllowRules.some((rule) => rule.pattern.test(target));
    if (!allowed) {
      return {
        blocked: true,
        reason: `Blocked: no allow rule matched for ${toolName}.\nCommand: ${target}\nAllowed patterns: ${toolAllowRules.map((r) => r.original).join(', ')}`,
      };
    }
  }

  return { blocked: false };
}
