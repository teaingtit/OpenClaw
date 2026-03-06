#!/usr/bin/env node
/**
 * Report token usage by agent for the last N days or last 24 hours.
 * Reads session logs from ~/.openclaw (no gateway required).
 *
 * Usage: node --import tsx scripts/ops/usage-by-agent.ts [--days 1] [--json]
 *        node --import tsx scripts/ops/usage-by-agent.ts [--hours 24] [--json]
 */

import { loadConfig } from "../../src/config/config.js";
import { listAgentsForGateway } from "../../src/gateway/session-utils.js";
import { discoverAllSessions, loadSessionCostSummary } from "../../src/infra/session-cost-usage.js";

const args = process.argv.slice(2);
const daysIdx = args.indexOf("--days");
const hoursIdx = args.indexOf("--hours");
const days = daysIdx >= 0 && args[daysIdx + 1] ? Number(args[daysIdx + 1]) : 0;
const hours = hoursIdx >= 0 && args[hoursIdx + 1] ? Number(args[hoursIdx + 1]) : 24;
const json = args.includes("--json");

const now = Date.now();
const dayMs = 24 * 60 * 60 * 1000;
const startMs = days > 0 ? now - days * dayMs : now - hours * 60 * 60 * 1000;
const endMs = now;

type Totals = {
  input: number;
  output: number;
  totalTokens: number;
  totalCost: number;
};

function formatDate(ms: number): string {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")} ${String(d.getUTCHours()).padStart(2, "0")}:${String(d.getUTCMinutes()).padStart(2, "0")}Z`;
}

async function main() {
  const config = loadConfig();
  const { agents } = listAgentsForGateway(config);

  const byAgent = new Map<string, Totals>();

  for (const agent of agents) {
    const sessions = await discoverAllSessions({
      agentId: agent.id,
      startMs,
      endMs,
    });

    let input = 0;
    let output = 0;
    let totalTokens = 0;
    let totalCost = 0;

    for (const session of sessions) {
      const summary = await loadSessionCostSummary({
        sessionId: session.sessionId,
        sessionFile: session.sessionFile,
        config,
        agentId: agent.id,
        startMs,
        endMs,
      });
      if (summary) {
        input += summary.input ?? 0;
        output += summary.output ?? 0;
        totalTokens += summary.totalTokens ?? 0;
        totalCost += summary.totalCost ?? 0;
      }
    }

    if (totalTokens > 0 || totalCost > 0) {
      byAgent.set(agent.id, { input, output, totalTokens, totalCost });
    }
  }

  const totals: Totals = {
    input: 0,
    output: 0,
    totalTokens: 0,
    totalCost: 0,
  };
  for (const t of byAgent.values()) {
    totals.input += t.input;
    totals.output += t.output;
    totals.totalTokens += t.totalTokens;
    totals.totalCost += t.totalCost;
  }

  const periodLabel = days > 0 ? `last ${days} day(s)` : `last ${hours} hour(s)`;
  const startDate = formatDate(startMs);
  const endDate = formatDate(endMs);

  if (json) {
    const byAgentList = Array.from(byAgent.entries())
      .map(([agentId, t]) => ({
        agentId,
        totalTokens: t.totalTokens,
        totalCost: t.totalCost,
        input: t.input,
        output: t.output,
      }))
      .toSorted((a, b) => b.totalTokens - a.totalTokens);

    console.log(
      JSON.stringify(
        {
          period: periodLabel,
          startMs,
          endMs,
          startDate,
          endDate,
          totals: {
            totalTokens: totals.totalTokens,
            totalCost: totals.totalCost,
          },
          byAgent: byAgentList,
        },
        null,
        2,
      ),
    );
    return;
  }

  console.log(`Usage (${periodLabel}: ${startDate} → ${endDate})\n`);
  console.log(
    `Total: ${totals.totalTokens.toLocaleString()} tokens, $${totals.totalCost.toFixed(4)} USD\n`,
  );

  if (byAgent.size === 0) {
    console.log("No per-agent usage in this period.");
    return;
  }

  const sorted = Array.from(byAgent.entries()).toSorted(
    (a, b) => b[1].totalTokens - a[1].totalTokens,
  );

  console.log("By agent (highest token usage first):");
  for (const [agentId, t] of sorted) {
    console.log(
      `  ${agentId}: ${t.totalTokens.toLocaleString()} tokens, $${t.totalCost.toFixed(4)} USD`,
    );
  }

  const top = sorted[0];
  if (top && top[1].totalTokens > 0) {
    console.log(`\nTop consumer (likely cause of limit): ${top[0]}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
