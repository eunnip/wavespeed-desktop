/**
 * Iterator node — container node that executes an internal sub-workflow
 * multiple times, aggregating results across iterations.
 */
import {
  BaseNodeHandler,
  type NodeExecutionContext,
  type NodeExecutionResult,
} from "../base";
import type { NodeTypeDefinition } from "../../../../src/workflow/types/node-defs";
import type { ExposedParam } from "../../../../src/workflow/types/workflow";
import type { NodeRegistry } from "../registry";
import { getChildNodes } from "../../db/node.repo";
import { getInternalEdges } from "../../db/edge.repo";
import { topologicalLevels } from "../../engine/scheduler";

export const iteratorDef: NodeTypeDefinition = {
  type: "control/iterator",
  category: "control",
  label: "Iterator",
  inputs: [],
  outputs: [],
  params: [
    {
      key: "iterationCount",
      label: "Iteration Count",
      type: "number",
      default: 1,
      validation: { min: 1 },
    },
    {
      key: "iterationMode",
      label: "Iteration Mode",
      type: "string",
      default: "fixed",
    },
    {
      key: "exposedInputs",
      label: "Exposed Inputs",
      type: "string",
      default: "[]",
    },
    {
      key: "exposedOutputs",
      label: "Exposed Outputs",
      type: "string",
      default: "[]",
    },
  ],
};

export class IteratorNodeHandler extends BaseNodeHandler {
  constructor(private registry: NodeRegistry) {
    super(iteratorDef);
  }

  async execute(ctx: NodeExecutionContext): Promise<NodeExecutionResult> {
    const start = Date.now();

    // 1. Parse iteration config from params
    const iterationMode = String(ctx.params.iterationMode ?? "fixed");
    const fixedCount = Math.max(1, Number(ctx.params.iterationCount) || 1);
    const exposedInputs = this.parseExposedParams(ctx.params.exposedInputs);
    const exposedOutputs = this.parseExposedParams(ctx.params.exposedOutputs);

    // 2. Load child nodes and internal edges
    const childNodes = getChildNodes(ctx.nodeId);
    const internalEdges = getInternalEdges(ctx.workflowId);

    // Filter internal edges to only those between our child nodes
    const childNodeIds = childNodes.map((n) => n.id);
    const childNodeIdSet = new Set(childNodeIds);
    const relevantEdges = internalEdges.filter(
      (e) => childNodeIdSet.has(e.sourceNodeId) && childNodeIdSet.has(e.targetNodeId),
    );

    if (childNodes.length === 0) {
      return {
        status: "success",
        outputs: {},
        durationMs: Date.now() - start,
        cost: 0,
      };
    }

    // 3. Topologically sort child nodes
    const simpleEdges = relevantEdges.map((e) => ({
      sourceNodeId: e.sourceNodeId,
      targetNodeId: e.targetNodeId,
    }));
    const levels = topologicalLevels(childNodeIds, simpleEdges);

    // 4. Build lookup maps
    const childNodeMap = new Map(childNodes.map((n) => [n.id, n]));

    // Build input routing: map from subNodeId -> paramKey -> external value
    // In auto mode, store the raw values (may be arrays) for per-iteration slicing
    const inputRoutingRaw = new Map<string, Map<string, unknown>>();
    for (const ep of exposedInputs) {
      const externalValue = ctx.inputs[ep.namespacedKey];
      if (externalValue !== undefined) {
        if (!inputRoutingRaw.has(ep.subNodeId)) {
          inputRoutingRaw.set(ep.subNodeId, new Map());
        }
        inputRoutingRaw.get(ep.subNodeId)!.set(ep.paramKey, externalValue);
      }
    }

    // 5. Determine iteration count
    let iterationCount: number;
    // Collect all external input values for auto-mode analysis
    const allExternalValues: unknown[] = [];
    for (const ep of exposedInputs) {
      const v = ctx.inputs[ep.namespacedKey];
      if (v !== undefined) allExternalValues.push(v);
    }

    if (iterationMode === "auto") {
      // Find the longest array among external inputs
      const arrayLengths = allExternalValues
        .filter((v) => Array.isArray(v))
        .map((v) => (v as unknown[]).length);

      if (arrayLengths.length === 0) {
        // No array inputs found — if there are any inputs at all, run once; otherwise error
        if (allExternalValues.length > 0) {
          iterationCount = 1;
        } else {
          return {
            status: "error",
            outputs: {},
            durationMs: Date.now() - start,
            cost: 0,
            error: "Auto mode: no external inputs connected. Connect an array input or switch to fixed mode.",
          };
        }
      } else {
        iterationCount = Math.max(...arrayLengths);
        // Empty array → 0 iterations
        if (iterationCount === 0) {
          return {
            status: "success",
            outputs: {},
            durationMs: Date.now() - start,
            cost: 0,
          };
        }
      }
    } else {
      iterationCount = fixedCount;
    }

    // 6. Execute iterations
    const iterationResults: Array<Record<string, unknown>> = [];
    let totalCost = 0;

    for (let i = 0; i < iterationCount; i++) {
      // Track outputs per sub-node for this iteration (for internal edge resolution)
      const subNodeOutputs = new Map<string, Record<string, unknown>>();

      // Execute sub-nodes level by level
      let iterationFailed = false;
      let failedSubNodeId = "";
      let failedError = "";

      for (const level of levels) {
        if (iterationFailed) break;

        for (const subNodeId of level) {
          if (iterationFailed) break;

          const subNode = childNodeMap.get(subNodeId);
          if (!subNode) continue;

          const handler = this.registry.getHandler(subNode.nodeType);
          if (!handler) {
            return {
              status: "error",
              outputs: {},
              durationMs: Date.now() - start,
              cost: totalCost,
              error: `No handler found for sub-node type: ${subNode.nodeType} (node: ${subNodeId})`,
            };
          }

          // Build params for this sub-node: base params + external inputs + iteration index
          const subParams: Record<string, unknown> = { ...subNode.params };

          // Inject external input values (with auto-mode array slicing)
          const externalInputs = inputRoutingRaw.get(subNodeId);
          if (externalInputs) {
            for (const [paramKey, rawValue] of externalInputs) {
              if (iterationMode === "auto" && Array.isArray(rawValue)) {
                // Slice: use element at index i, pad with last element if shorter
                const arr = rawValue as unknown[];
                subParams[paramKey] = arr.length > 0 ? arr[Math.min(i, arr.length - 1)] : undefined;
              } else if (iterationMode === "fixed" && Array.isArray(rawValue)) {
                // Fixed mode with array: cycle with modulo
                const arr = rawValue as unknown[];
                subParams[paramKey] = arr.length > 0 ? arr[i % arr.length] : undefined;
              } else {
                // Non-array: broadcast same value to all iterations
                subParams[paramKey] = rawValue;
              }
            }
          }

          // Inject iteration index
          subParams.__iterationIndex = i;

          // Resolve internal edge inputs from upstream sub-node outputs
          const subInputs = this.resolveSubNodeInputs(
            subNodeId,
            relevantEdges,
            subNodeOutputs,
          );

          // Also inject unconnected param defaults (already in subParams from subNode.params)
          // External inputs that aren't connected fall back to the sub-node's default value
          // which is already present in subNode.params

          const subCtx: NodeExecutionContext = {
            nodeId: subNodeId,
            nodeType: subNode.nodeType,
            params: subParams,
            inputs: subInputs,
            workflowId: ctx.workflowId,
            abortSignal: ctx.abortSignal,
            onProgress: (_progress, message) => {
              // Forward sub-node progress as part of overall iteration progress
              const iterationProgress = (i / iterationCount) * 100;
              ctx.onProgress(iterationProgress, message);
            },
          };

          try {
            const result = await handler.execute(subCtx);
            totalCost += result.cost;

            if (result.status === "error") {
              iterationFailed = true;
              failedSubNodeId = subNodeId;
              failedError = result.error || "Unknown sub-node error";
              break;
            }

            // Store sub-node outputs for downstream internal edge resolution
            subNodeOutputs.set(subNodeId, result.outputs);
          } catch (error) {
            return {
              status: "error",
              outputs: {},
              durationMs: Date.now() - start,
              cost: totalCost,
              error: `Sub-node ${subNodeId} threw: ${error instanceof Error ? error.message : String(error)}`,
            };
          }
        }
      }

      if (iterationFailed) {
        return {
          status: "error",
          outputs: {},
          durationMs: Date.now() - start,
          cost: totalCost,
          error: `Sub-node ${failedSubNodeId} failed: ${failedError}`,
        };
      }

      // Collect exposed output values for this iteration
      const iterOutputs: Record<string, unknown> = {};
      for (const ep of exposedOutputs) {
        const nodeOutputs = subNodeOutputs.get(ep.subNodeId);
        if (nodeOutputs) {
          // Key by handle ID format "output-{namespacedKey}" so the executor's
          // resolveInputs can find the value via edge.sourceOutputKey
          iterOutputs[`output-${ep.namespacedKey}`] = nodeOutputs[ep.paramKey];
        }
      }
      iterationResults.push(iterOutputs);

      // Report progress
      ctx.onProgress(((i + 1) / iterationCount) * 100, `Iteration ${i + 1}/${iterationCount} complete`);
    }

    // 6. Aggregate results — ALWAYS output arrays regardless of iteration count
    //    This ensures downstream nodes always receive a consistent format.
    //    N=1 → ["value"], N=3 → ["v1","v2","v3"], N=0 → []
    const outputs: Record<string, unknown> = {};
    for (const ep of exposedOutputs) {
      const handleKey = `output-${ep.namespacedKey}`;
      outputs[handleKey] = iterationResults.map((r) => r[handleKey]);
    }

    return {
      status: "success",
      outputs,
      resultMetadata: { ...outputs },
      durationMs: Date.now() - start,
      cost: totalCost,
    };
  }

  /**
   * Resolve inputs for a sub-node from upstream sub-node outputs via internal edges.
   */
  private resolveSubNodeInputs(
    subNodeId: string,
    internalEdges: { sourceNodeId: string; targetNodeId: string; sourceOutputKey: string; targetInputKey: string }[],
    subNodeOutputs: Map<string, Record<string, unknown>>,
  ): Record<string, unknown> {
    const inputs: Record<string, unknown> = {};
    const incomingEdges = internalEdges.filter((e) => e.targetNodeId === subNodeId);

    for (const edge of incomingEdges) {
      const sourceOutputs = subNodeOutputs.get(edge.sourceNodeId);
      if (!sourceOutputs) continue;

      const value = sourceOutputs[edge.sourceOutputKey];
      if (value === undefined) continue;

      // Parse target handle key the same way the main executor does
      const targetKey = edge.targetInputKey;
      if (targetKey.startsWith("param-")) {
        inputs[targetKey.slice(6)] = value;
      } else if (targetKey.startsWith("input-")) {
        inputs[targetKey.slice(6)] = value;
      } else {
        inputs[targetKey] = value;
      }
    }

    return inputs;
  }

  /**
   * Parse exposed params from JSON string stored in node params.
   */
  private parseExposedParams(value: unknown): ExposedParam[] {
    if (typeof value === "string") {
      try {
        return JSON.parse(value) as ExposedParam[];
      } catch {
        return [];
      }
    }
    if (Array.isArray(value)) {
      return value as ExposedParam[];
    }
    return [];
  }
}
