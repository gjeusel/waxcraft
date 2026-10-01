/**
 * complex-mcp-setup — registers MCP servers whose configuration mcp.json cannot express, such as
 * values Pi does not expand from `${VAR}`. Each server is registered only when what it needs is
 * available. Servers registered here are invisible to `pi mcp list` and `pi mcp login`, which do
 * not load extensions: use `/mcp` inside a session.
 */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

/**
 * Slack's official server, through a personal Slack app whose client ID comes from
 * `SLACK_MCP_CLIENT_ID`: Pi does not expand `${VAR}` in `oauth.clientId`.
 */
function registerSlack(pi: ExtensionAPI): void {
  const clientId = process.env.SLACK_MCP_CLIENT_ID;
  if (!clientId) return;

  pi.registerMcpServer('slack', {
    url: 'https://mcp.slack.com/mcp',
    // Must match the redirect URL registered on the Slack app.
    oauth: { clientId, callbackUrl: 'http://localhost:3118/callback' },
  });
}

export default function complexMcpSetup(pi: ExtensionAPI): void {
  registerSlack(pi);
}
