/**
 * IteratorNodeContainer — ReactFlow custom node for the Iterator container.
 *
 * Exposed params appear as "capsule" handles on the left/right border:
 *   [●──param name──●]
 *
 * IN capsules (left border):
 *   Left dot  = external target (outside nodes connect here)
 *   Right dot = internal source (auto-connected to child node input)
 *
 * OUT capsules (right border):
 *   Left dot  = internal target (auto-connected from child node output)
 *   Right dot = external source (outside nodes connect from here)
 *
 * When a param is exposed via the picker, an internal edge is auto-created
 * between the capsule's inner handle and the child node's corresponding handle.
 */
import React, {
  memo,
  useCallback,
  useRef,
  useState,
  useMemo,
  useEffect,
} from "react";
import { createPortal } from "react-dom";
import { useTranslation } from "react-i18next";
import { Handle, Position, useReactFlow, useUpdateNodeInternals, type NodeProps } from "reactflow";
import { useWorkflowStore } from "../../../stores/workflow.store";
import { useUIStore } from "../../../stores/ui.store";
import { useExecutionStore } from "../../../stores/execution.store";
import type { PortDefinition } from "@/workflow/types/node-defs";
import type { NodeStatus } from "@/workflow/types/execution";
import type { ExposedParam } from "@/workflow/types/workflow";
import {
  Tooltip,
  TooltipTrigger,
  TooltipContent,
} from "@/components/ui/tooltip";
import { ChevronDown, ChevronUp } from "lucide-react";

/* ── constants ─────────────────────────────────────────────────────── */

const MIN_ITERATOR_WIDTH = 600;
const MIN_ITERATOR_HEIGHT = 400;
const CHILD_PADDING = 40;
const TITLE_BAR_HEIGHT = 40;
const CAPSULE_HEIGHT = 28;
const CAPSULE_GAP = 6;
const CAPSULE_TOP_OFFSET = TITLE_BAR_HEIGHT + 56;
const HANDLE_DOT = 10;
const CAPSULE_LABEL_WIDTH = 110; // fixed width for capsule label area

/* ── types ─────────────────────────────────────────────────────────── */

export interface IteratorNodeData {
  nodeType: string;
  label: string;
  params: Record<string, unknown>;
  childNodeIds?: string[];
  inputDefinitions?: PortDefinition[];
  outputDefinitions?: PortDefinition[];
  paramDefinitions?: unknown[];
}

/* ── Gear icon ─────────────────────────────────────────────────────── */

const GearIcon = ({ size = 12 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
  </svg>
);

/* ── Expose-param picker — floats above the iterator ───────────────── */

function ExposeParamPicker({
  iteratorId,
  direction,
  onClose,
}: {
  iteratorId: string;
  direction: "input" | "output";
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const nodes = useWorkflowStore((s) => s.nodes);
  const exposeParam = useWorkflowStore((s) => s.exposeParam);
  const unexposeParam = useWorkflowStore((s) => s.unexposeParam);

  const iteratorNode = nodes.find((n) => n.id === iteratorId);
  const iteratorParams = (iteratorNode?.data?.params ?? {}) as Record<string, unknown>;
  const childNodes = nodes.filter((n) => n.parentNode === iteratorId);

  const exposedList: ExposedParam[] = useMemo(() => {
    const key = direction === "input" ? "exposedInputs" : "exposedOutputs";
    try {
      const raw = iteratorParams[key];
      return typeof raw === "string" ? JSON.parse(raw) : Array.isArray(raw) ? raw : [];
    } catch { return []; }
  }, [iteratorParams, direction]);

  const isExposed = useCallback(
    (subNodeId: string, paramKey: string) =>
      exposedList.some((p) => p.subNodeId === subNodeId && p.paramKey === paramKey),
    [exposedList],
  );

  const handleToggle = useCallback(
    (subNodeId: string, subNodeLabel: string, paramKey: string, dataType: string) => {
      const nk = `${subNodeLabel}.${paramKey}`;
      if (isExposed(subNodeId, paramKey)) {
        unexposeParam(iteratorId, nk, direction);
      } else {
        exposeParam(iteratorId, {
          subNodeId, subNodeLabel, paramKey, namespacedKey: nk, direction,
          dataType: dataType as ExposedParam["dataType"],
        });
      }
    },
    [isExposed, exposeParam, unexposeParam, iteratorId, direction],
  );

  if (childNodes.length === 0) {
    return (
      <div className="nodrag nopan bg-[hsl(var(--popover))] border border-border rounded-lg shadow-2xl p-3 min-w-[220px]"
        onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-2">
          <span className="text-[11px] font-semibold text-foreground">
            {direction === "input" ? t("workflow.configureInputs", "Configure Inputs") : t("workflow.configureOutputs", "Configure Outputs")}
          </span>
          <button onClick={onClose} className="text-muted-foreground hover:text-foreground p-0.5 rounded">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
          </button>
        </div>
        <p className="text-[10px] text-muted-foreground">{t("workflow.noChildNodes", "Add child nodes first to expose their parameters")}</p>
      </div>
    );
  }

  return (
    <div className="nodrag nopan bg-[hsl(var(--popover))] border border-border rounded-lg shadow-2xl min-w-[260px] max-h-[320px] overflow-y-auto"
      onClick={(e) => e.stopPropagation()}>
      <div className="flex items-center justify-between px-3 py-2 border-b border-border/50 sticky top-0 bg-[hsl(var(--popover))]">
        <span className="text-[11px] font-semibold text-foreground">
          {direction === "input" ? t("workflow.configureInputs", "Configure Inputs") : t("workflow.configureOutputs", "Configure Outputs")}
        </span>
        <button onClick={onClose} className="text-muted-foreground hover:text-foreground p-0.5 rounded hover:bg-muted/60">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>
        </button>
      </div>
      <div className="p-2 space-y-2">
        {childNodes.map((child) => {
          const childLabel = String(child.data?.label ?? child.id.slice(0, 8));
          const paramDefs = (child.data?.paramDefinitions ?? []) as Array<{ key: string; label: string; dataType?: string }>;
          const childInputDefs = (child.data?.inputDefinitions ?? []) as PortDefinition[];
          const childOutputDefs = (child.data?.outputDefinitions ?? []) as PortDefinition[];
          const modelSchema = (child.data?.modelInputSchema ?? []) as Array<{ name: string; label?: string; type?: string; mediaType?: string; required?: boolean }>;

          let items: Array<{ key: string; label: string; dataType: string }>;

          if (direction === "input") {
            const modelItems = modelSchema.map((m) => ({
              key: m.name,
              label: m.label || m.name.split("_").map((w: string) => w.charAt(0).toUpperCase() + w.slice(1)).join(" "),
              dataType: m.mediaType ?? m.type ?? "any",
            }));
            const inputPortItems = childInputDefs.map((d) => ({ key: d.key, label: d.label, dataType: d.dataType }));
            if (modelItems.length === 0) {
              const visibleParams = paramDefs
                .filter((d) => !d.key.startsWith("__") && d.key !== "modelId")
                .map((d) => ({ key: d.key, label: d.label, dataType: d.dataType ?? "any" }));
              items = [...visibleParams, ...inputPortItems];
            } else {
              items = [...modelItems, ...inputPortItems];
            }
          } else {
            items = childOutputDefs.map((d) => ({ key: d.key, label: d.label, dataType: d.dataType }));
          }

          if (items.length === 0) return null;

          return (
            <div key={child.id}>
              <div className="text-[9px] text-muted-foreground/60 uppercase tracking-wider font-semibold px-1 mb-1">{childLabel}</div>
              {items.map((item) => (
                <button
                  key={`${child.id}-${item.key}`}
                  onClick={() => handleToggle(child.id, childLabel, item.key, item.dataType)}
                  className={`w-full flex items-center gap-2 px-2 py-1.5 rounded text-[11px] transition-colors ${
                    isExposed(child.id, item.key)
                      ? "bg-cyan-500/15 text-cyan-400"
                      : "text-foreground/70 hover:bg-muted/60"
                  }`}
                >
                  <div className={`w-2.5 h-2.5 rounded-full flex-shrink-0 border ${isExposed(child.id, item.key) ? "bg-cyan-500 border-cyan-400" : "bg-transparent border-muted-foreground/30"}`} />
                  <span className="truncate flex-1 text-left">{item.label}</span>
                  {isExposed(child.id, item.key) && (
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" className="flex-shrink-0 text-cyan-400"><polyline points="20 6 9 17 4 12" /></svg>
                  )}
                </button>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ── Portal wrapper — positions a floating panel relative to the iterator node ── */

function PickerPortal({
  nodeRef,
  side,
  offsetTop,
  children,
}: {
  nodeRef: React.RefObject<HTMLDivElement>;
  side: "left" | "right";
  offsetTop: number;
  children: React.ReactNode;
}) {
  const [pos, setPos] = useState<{ top: number; left?: number; right?: number }>({ top: 0 });
  const portalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const update = () => {
      const rect = nodeRef.current?.getBoundingClientRect();
      if (!rect) return;
      if (side === "left") {
        setPos({ top: rect.top + offsetTop, left: rect.left + 8 });
      } else {
        setPos({ top: rect.top + offsetTop, right: window.innerWidth - rect.right + 8 });
      }
    };
    update();
    const viewport = nodeRef.current?.closest(".react-flow__viewport");
    let mo: MutationObserver | undefined;
    if (viewport) {
      mo = new MutationObserver(update);
      mo.observe(viewport, { attributes: true, attributeFilter: ["style"] });
    }
    window.addEventListener("resize", update);
    return () => { mo?.disconnect(); window.removeEventListener("resize", update); };
  }, [nodeRef, side, offsetTop]);

  return (
    <div
      ref={portalRef}
      className="nodrag nopan fixed"
      style={{ ...pos, zIndex: 99999 }}
      onClick={(e) => e.stopPropagation()}
      onMouseDown={(e) => e.stopPropagation()}
    >
      {children}
    </div>
  );
}

/* ── Capsule handle style helpers ──────────────────────────────────── */

const dotStyle = (connected: boolean): React.CSSProperties => ({
  width: HANDLE_DOT,
  height: HANDLE_DOT,
  borderRadius: "50%",
  border: "2px solid hsl(var(--primary))",
  background: connected ? "hsl(var(--primary))" : "hsl(var(--card))",
  minWidth: HANDLE_DOT,
  minHeight: HANDLE_DOT,
  position: "relative" as const,
  top: "auto",
  left: "auto",
  right: "auto",
  bottom: "auto",
  transform: "none",
  zIndex: 40,
});

/* ── main component ────────────────────────────────────────────────── */

function IteratorNodeContainerComponent({
  id,
  data,
  selected,
}: NodeProps<IteratorNodeData>) {
  const { t } = useTranslation();
  const nodeRef = useRef<HTMLDivElement>(null);
  const [resizing, setResizing] = useState(false);
  const [hovered, setHovered] = useState(false);
  const [editingCount, setEditingCount] = useState(false);
  const [countDraft, setCountDraft] = useState("");
  const countInputRef = useRef<HTMLInputElement>(null);
  const [showInputPicker, setShowInputPicker] = useState(false);
  const [showOutputPicker, setShowOutputPicker] = useState(false);
  const { getViewport, setNodes } = useReactFlow();
  const updateNodeInternals = useUpdateNodeInternals();
  const updateNodeParams = useWorkflowStore((s) => s.updateNodeParams);
  const workflowId = useWorkflowStore((s) => s.workflowId);
  const removeNode = useWorkflowStore((s) => s.removeNode);
  const toggleNodePalette = useUIStore((s) => s.toggleNodePalette);
  const edges = useWorkflowStore((s) => s.edges);
  const status = useExecutionStore(
    (s) => s.nodeStatuses[id] ?? "idle",
  ) as NodeStatus;
  const progress = useExecutionStore((s) => s.progressMap[id]);
  const errorMessage = useExecutionStore((s) => s.errorMessages[id]);
  const { runNode, cancelNode, retryNode, continueFrom } = useExecutionStore();
  const running = status === "running";

  const iterationCount = Number(data.params?.iterationCount ?? 1);
  const iterationMode = String(data.params?.iterationMode ?? "fixed");
  const savedWidth = (data.params?.__nodeWidth as number) ?? MIN_ITERATOR_WIDTH;
  const savedHeight = (data.params?.__nodeHeight as number) ?? MIN_ITERATOR_HEIGHT;
  const collapsed = (data.params?.__nodeCollapsed as boolean | undefined) ?? false;
  const shortId = id.slice(0, 8);

  const inputDefs = useMemo(() => {
    // Reconstruct from exposedInputs params (source of truth) to be resilient
    // against data.inputDefinitions being reset by other state updates
    try {
      const raw = data.params?.exposedInputs;
      const list: ExposedParam[] = typeof raw === "string" ? JSON.parse(raw) : Array.isArray(raw) ? raw : [];
      return list.map((ep): PortDefinition => {
        const readableParam = ep.paramKey.split("_").map((w: string) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
        const shortLabel = ep.subNodeLabel.includes("/") ? ep.subNodeLabel.split("/").pop()! : ep.subNodeLabel;
        return { key: ep.namespacedKey, label: `${readableParam} · ${shortLabel}`, dataType: ep.dataType, required: false };
      });
    } catch { return data.inputDefinitions ?? []; }
  }, [data.params?.exposedInputs, data.inputDefinitions]);

  const outputDefs = useMemo(() => {
    try {
      const raw = data.params?.exposedOutputs;
      const list: ExposedParam[] = typeof raw === "string" ? JSON.parse(raw) : Array.isArray(raw) ? raw : [];
      return list.map((ep): PortDefinition => {
        const readableParam = ep.paramKey.split("_").map((w: string) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
        const shortLabel = ep.subNodeLabel.includes("/") ? ep.subNodeLabel.split("/").pop()! : ep.subNodeLabel;
        return { key: ep.namespacedKey, label: `${readableParam} · ${shortLabel}`, dataType: ep.dataType, required: false };
      });
    } catch { return data.outputDefinitions ?? []; }
  }, [data.params?.exposedOutputs, data.outputDefinitions]);
  const childNodeIds = data.childNodeIds ?? [];
  const hasChildren = childNodeIds.length > 0;

  /* ── Force ReactFlow to recalculate handle positions when ports change ── */
  const portFingerprint = useMemo(
    () => inputDefs.map((d) => d.key).join(",") + "|" + outputDefs.map((d) => d.key).join(","),
    [inputDefs, outputDefs],
  );
  useEffect(() => {
    // After new handles render, tell ReactFlow to update its internal handle cache
    requestAnimationFrame(() => updateNodeInternals(id));
  }, [portFingerprint, id, updateNodeInternals]);

  /* ── Collapse toggle ───────────────────────────────────────────── */
  const setCollapsed = useCallback(
    (value: boolean) => updateNodeParams(id, { ...data.params, __nodeCollapsed: value }),
    [id, data.params, updateNodeParams],
  );
  const toggleCollapsed = useCallback(
    (e: React.MouseEvent) => { e.stopPropagation(); setCollapsed(!collapsed); },
    [collapsed, setCollapsed],
  );

  /* ── Effective size ─────────────────────────────────────────────── */
  const effectiveWidth = savedWidth;
  const effectiveHeight = collapsed ? TITLE_BAR_HEIGHT : savedHeight;

  /* ── Auto-expand: observe child DOM size changes ───────────────── */
  useEffect(() => {
    if (collapsed || childNodeIds.length === 0) return;
    const updateBB = useWorkflowStore.getState().updateBoundingBox;
    const observer = new ResizeObserver(() => { updateBB(id); });
    for (const cid of childNodeIds) {
      const el = document.querySelector(`[data-id="${cid}"]`) as HTMLElement | null;
      if (el) observer.observe(el);
    }
    return () => observer.disconnect();
  }, [id, childNodeIds, collapsed]);

  /* ── Iteration count editing ───────────────────────────────────── */
  const startEditingCount = useCallback((e: React.MouseEvent) => {
    e.stopPropagation(); setCountDraft(String(iterationCount)); setEditingCount(true);
  }, [iterationCount]);

  useEffect(() => {
    if (editingCount && countInputRef.current) { countInputRef.current.focus(); countInputRef.current.select(); }
  }, [editingCount]);

  const commitCount = useCallback(() => {
    const val = Math.max(1, Math.floor(Number(countDraft) || 1));
    updateNodeParams(id, { ...data.params, iterationCount: val });
    setEditingCount(false);
  }, [countDraft, id, data.params, updateNodeParams]);

  const onCountKeyDown = useCallback(
    (e: React.KeyboardEvent) => { if (e.key === "Enter") commitCount(); if (e.key === "Escape") setEditingCount(false); },
    [commitCount],
  );

  /* ── Actions ───────────────────────────────────────────────────── */
  const onRun = useCallback(async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (running) cancelNode(workflowId ?? "", id); else runNode(workflowId ?? "", id);
  }, [running, workflowId, id, runNode, cancelNode]);

  const onRunFromHere = useCallback(async (e: React.MouseEvent) => {
    e.stopPropagation(); continueFrom(workflowId ?? "", id);
  }, [workflowId, id, continueFrom]);

  const onDelete = useCallback((e: React.MouseEvent) => {
    e.stopPropagation(); removeNode(id);
  }, [removeNode, id]);

  const handleAddNodeInside = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    useUIStore.getState().setPendingIteratorParentId(id);
    toggleNodePalette();
  }, [toggleNodePalette, id]);

  /* ── Resize handler ────────────────────────────────────────────── */
  const onEdgeResizeStart = useCallback(
    (e: React.MouseEvent, xDir: number, yDir: number) => {
      e.stopPropagation(); e.preventDefault();
      const el = nodeRef.current; if (!el) return;
      setResizing(true);
      const startX = e.clientX, startY = e.clientY;
      const startW = savedWidth;
      const startH = savedHeight;
      const zoom = getViewport().zoom;

      // Capture the starting position of the iterator node
      const startPos = (() => {
        const n = useWorkflowStore.getState().nodes.find((nd) => nd.id === id);
        return n ? { ...n.position } : { x: 0, y: 0 };
      })();

      const onMove = (ev: MouseEvent) => {
        const dx = (ev.clientX - startX) / zoom;
        const dy = (ev.clientY - startY) / zoom;
        const newW = xDir !== 0 ? Math.max(MIN_ITERATOR_WIDTH, startW + dx * xDir) : startW;
        const newH = yDir !== 0 ? Math.max(MIN_ITERATOR_HEIGHT, startH + dy * yDir) : startH;
        const newX = xDir === -1 ? startPos.x + (startW - newW) : startPos.x;
        const newY = yDir === -1 ? startPos.y + (startH - newH) : startPos.y;

        setNodes((nds) => nds.map((n) => {
          if (n.id !== id) return n;
          const p = { ...n.data.params, __nodeWidth: newW, __nodeHeight: newH };
          return { ...n, position: { x: newX, y: newY }, data: { ...n.data, params: p } };
        }));
      };

      const onUp = (ev: MouseEvent) => {
        document.removeEventListener("mousemove", onMove);
        document.removeEventListener("mouseup", onUp);
        setResizing(false);

        const dx = (ev.clientX - startX) / zoom;
        const dy = (ev.clientY - startY) / zoom;
        const finalW = xDir !== 0 ? Math.max(MIN_ITERATOR_WIDTH, startW + dx * xDir) : startW;
        const finalH = yDir !== 0 ? Math.max(MIN_ITERATOR_HEIGHT, startH + dy * yDir) : startH;

        useWorkflowStore.setState({ isDirty: true });

        // Re-clamp child nodes
        const { nodes: currentNodes } = useWorkflowStore.getState();
        const clampPad = 10;
        const childUpdates: Array<{ nodeId: string; pos: { x: number; y: number } }> = [];
        for (const cn of currentNodes) {
          if (cn.parentNode !== id) continue;
          const cw = (cn.data?.params?.__nodeWidth as number) ?? 300;
          const ch = (cn.data?.params?.__nodeHeight as number) ?? 80;
          const minCX = clampPad;
          const maxCX = Math.max(minCX, finalW - cw - clampPad);
          const minCY = TITLE_BAR_HEIGHT + clampPad;
          const maxCY = Math.max(minCY, finalH - ch - clampPad - 40);
          const cx = Math.min(Math.max(cn.position.x, minCX), maxCX);
          const cy = Math.min(Math.max(cn.position.y, minCY), maxCY);
          if (cx !== cn.position.x || cy !== cn.position.y) {
            childUpdates.push({ nodeId: cn.id, pos: { x: cx, y: cy } });
          }
        }
        if (childUpdates.length > 0) {
          useWorkflowStore.setState((state) => ({
            nodes: state.nodes.map((n) => {
              const upd = childUpdates.find((u) => u.nodeId === n.id);
              return upd ? { ...n, position: upd.pos } : n;
            }),
          }));
        }
      };
      document.addEventListener("mousemove", onMove);
      document.addEventListener("mouseup", onUp);
    },
    [id, getViewport, setNodes, savedWidth, savedHeight],
  );

  /* ── Capsule vertical position ─────────────────────────────────── */
  const getCapsuleTop = (index: number) =>
    CAPSULE_TOP_OFFSET + index * (CAPSULE_HEIGHT + CAPSULE_GAP);

  /* ── Exposed param lookup — maps namespacedKey → ExposedParam for tooltip info ── */
  const exposedParamMap = useMemo(() => {
    const map = new Map<string, ExposedParam>();
    for (const key of ["exposedInputs", "exposedOutputs"] as const) {
      try {
        const raw = data.params?.[key];
        const list: ExposedParam[] = typeof raw === "string" ? JSON.parse(raw) : Array.isArray(raw) ? raw : [];
        for (const ep of list) map.set(ep.namespacedKey, ep);
      } catch { /* ignore */ }
    }
    return map;
  }, [data.params]);

  /* ── Check if a handle has a connected edge ────────────────────── */
  const isHandleConnected = useCallback(
    (handleId: string, type: "source" | "target") =>
      edges.some((e) =>
        type === "source"
          ? e.source === id && e.sourceHandle === handleId
          : e.target === id && e.targetHandle === handleId,
      ),
    [edges, id],
  );

  /* ── Picker toggle helpers ─────────────────────────────────────── */
  const toggleInputPicker = useCallback((e: React.MouseEvent) => {
    e.stopPropagation(); setShowInputPicker((v) => !v); setShowOutputPicker(false);
  }, []);
  const toggleOutputPicker = useCallback((e: React.MouseEvent) => {
    e.stopPropagation(); setShowOutputPicker((v) => !v); setShowInputPicker(false);
  }, []);

  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => { setHovered(false); }}
      className="relative"
    >
      {/* Invisible hover extension above */}
      <div className="absolute -top-10 left-0 right-0 h-10" />

      {/* ── Hover toolbar ──────────────────────────────────────── */}
      {hovered && (
        <div className="absolute -top-9 left-1/2 -translate-x-1/2 z-50 flex items-center gap-1">
          {running ? (
            <button onClick={onRun} className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-[11px] font-medium shadow-lg backdrop-blur-sm bg-red-500 text-white hover:bg-red-600 transition-all">
              <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="6" width="12" height="12" rx="1" /></svg>
              {t("workflow.stop", "Stop")}
            </button>
          ) : (
            <>
              <button onClick={onRun} className="flex items-center gap-1 px-3 py-1.5 rounded-full text-[11px] font-medium shadow-lg backdrop-blur-sm bg-blue-500 text-white hover:bg-blue-600 transition-all whitespace-nowrap">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><polygon points="6,3 20,12 6,21" /></svg>
                {t("workflow.run", "Run")}
              </button>
              <button onClick={onRunFromHere} className="flex items-center gap-1 px-3 py-1.5 rounded-full text-[11px] font-medium shadow-lg backdrop-blur-sm bg-green-600 text-white hover:bg-green-700 transition-all whitespace-nowrap">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><polygon points="4,4 14,12 4,20" /><polygon points="12,4 22,12 12,20" /></svg>
                {t("workflow.runFromHere", "Run from here")}
              </button>
              <button onClick={onDelete} className="flex items-center justify-center w-8 h-8 rounded-full shadow-lg backdrop-blur-sm bg-[hsl(var(--muted))] text-muted-foreground hover:bg-red-500/20 hover:text-red-400 transition-all" title={t("workflow.delete", "Delete")}>
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <polyline points="3 6 5 6 21 6" /><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
                  <line x1="10" y1="11" x2="10" y2="17" /><line x1="14" y1="11" x2="14" y2="17" />
                </svg>
              </button>
            </>
          )}
        </div>
      )}

      {/* ── Main container ─────────────────────────────────────── */}
      <div
        ref={nodeRef}
        className={`
          relative rounded-xl overflow-visible
          bg-[hsl(var(--card)/0.15)] text-[hsl(var(--card-foreground))]
          border-2 border-dashed
          ${resizing ? "" : "transition-all duration-300"}
          ${running ? "border-blue-500 animate-pulse-subtle" : ""}
          ${!running && selected ? "border-cyan-500 shadow-[0_0_20px_rgba(6,182,212,.25)] ring-1 ring-cyan-500/30" : ""}
          ${!running && !selected && status === "confirmed" ? "border-green-500/70" : ""}
          ${!running && !selected && status === "unconfirmed" ? "border-orange-500/70" : ""}
          ${!running && !selected && status === "error" ? "border-red-500/70" : ""}
          ${!running && !selected && (status === "idle" || !status) ? (hovered ? "border-cyan-500/40 shadow-lg" : "border-[hsl(var(--muted-foreground)/0.3)]") : ""}
        `}
        style={{ width: effectiveWidth, height: effectiveHeight, fontSize: 13, ...(collapsed ? { overflow: "hidden" } : {}) }}
      >

        {/* ── Title bar ──────────────────────────────────────── */}
        <div
          className={`flex items-center gap-1.5 px-3 select-none rounded-t-xl border-b border-dashed border-[hsl(var(--border)/0.5)]
            ${running ? "bg-blue-500/10" : status === "confirmed" ? "bg-green-500/8" : status === "error" ? "bg-red-500/8" : "bg-[hsl(var(--card)/0.6)]"}`}
          style={{ height: TITLE_BAR_HEIGHT }}
        >
          <span className={`w-2 h-2 rounded-full flex-shrink-0 ${running ? "bg-blue-500 animate-pulse" : status === "confirmed" ? "bg-green-500" : status === "error" ? "bg-red-500" : status === "unconfirmed" ? "bg-orange-500" : "bg-[hsl(var(--muted-foreground))] opacity-30"}`} />
          <button type="button" onClick={toggleCollapsed} className="nodrag nopan flex-shrink-0 p-1 rounded hover:bg-black/10 dark:hover:bg-white/10 transition-colors" title={collapsed ? t("workflow.expandNode", "Expand") : t("workflow.collapseNode", "Collapse")}>
            {collapsed ? <ChevronDown className="w-4 h-4 text-muted-foreground" /> : <ChevronUp className="w-4 h-4 text-muted-foreground" />}
          </button>
          <div className="rounded-md bg-cyan-500/15 p-1 flex-shrink-0">
            <svg className="w-3.5 h-3.5 text-cyan-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="17 1 21 5 17 9" /><path d="M3 11V9a4 4 0 0 1 4-4h14" />
              <polyline points="7 23 3 19 7 15" /><path d="M21 13v2a4 4 0 0 1-4 4H3" />
            </svg>
          </div>
          <span className="font-semibold text-[13px] truncate">{data.label || t("workflow.iterator", "Iterator")}</span>
          <span className="text-[10px] text-[hsl(var(--muted-foreground))] opacity-50 font-mono flex-shrink-0">{shortId}</span>
          <div className="flex-1" />

          {/* ── Config buttons: IN / OUT ── */}
          <Tooltip delayDuration={0}>
            <TooltipTrigger asChild>
              <button onClick={toggleInputPicker}
                className={`nodrag nopan flex items-center gap-1 px-2 py-1 rounded-md text-[10px] font-medium transition-colors ${
                  showInputPicker ? "bg-cyan-500/20 text-cyan-400" : "text-cyan-400/50 hover:text-cyan-400 hover:bg-cyan-500/10"
                }`}>
                <GearIcon size={10} />
                <span>{t("workflow.in", "IN")}</span>
                {inputDefs.length > 0 && <span className="px-1 py-0.5 rounded bg-cyan-500/20 text-[9px]">{inputDefs.length}</span>}
              </button>
            </TooltipTrigger>
            <TooltipContent side="bottom">{t("workflow.configureInputs", "Configure exposed input parameters")}</TooltipContent>
          </Tooltip>
          <Tooltip delayDuration={0}>
            <TooltipTrigger asChild>
              <button onClick={toggleOutputPicker}
                className={`nodrag nopan flex items-center gap-1 px-2 py-1 rounded-md text-[10px] font-medium transition-colors ${
                  showOutputPicker ? "bg-cyan-500/20 text-cyan-400" : "text-cyan-400/50 hover:text-cyan-400 hover:bg-cyan-500/10"
                }`}>
                <GearIcon size={10} />
                <span>{t("workflow.out", "OUT")}</span>
                {outputDefs.length > 0 && <span className="px-1 py-0.5 rounded bg-cyan-500/20 text-[9px]">{outputDefs.length}</span>}
              </button>
            </TooltipTrigger>
            <TooltipContent side="bottom">{t("workflow.configureOutputs", "Configure exposed output parameters")}</TooltipContent>
          </Tooltip>

          {/* ── Unified iteration mode + count capsule ── */}
          <Tooltip delayDuration={0}>
            <TooltipTrigger asChild>
              <div className={`nodrag nopan flex-shrink-0 ml-1 flex items-center h-7 rounded-full border overflow-hidden transition-all cursor-pointer select-none ${
                iterationMode === "auto"
                  ? "bg-gradient-to-r from-violet-500/15 to-amber-500/15 border-violet-500/30"
                  : "bg-cyan-500/8 border-cyan-500/20 hover:border-cyan-500/40"
              }`}>
                {/* Left half: mode toggle */}
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    const newMode = iterationMode === "fixed" ? "auto" : "fixed";
                    updateNodeParams(id, { ...data.params, iterationMode: newMode });
                  }}
                  className={`nodrag nopan flex items-center gap-1 px-2 h-full text-[10px] font-semibold tracking-wide uppercase transition-colors ${
                    iterationMode === "auto"
                      ? "text-violet-400 hover:bg-violet-500/15"
                      : "text-cyan-400/70 hover:bg-cyan-500/10"
                  }`}
                >
                  {iterationMode === "auto" ? (
                    <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor" className="flex-shrink-0">
                      <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
                    </svg>
                  ) : (
                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="flex-shrink-0">
                      <polyline points="17 1 21 5 17 9" /><path d="M3 11V9a4 4 0 0 1 4-4h14" />
                      <polyline points="7 23 3 19 7 15" /><path d="M21 13v2a4 4 0 0 1-4 4H3" />
                    </svg>
                  )}
                  {iterationMode === "auto" ? "Auto" : "Fixed"}
                </button>
                {/* Divider + count — only in fixed mode */}
                {iterationMode === "fixed" && (
                  <>
                    <div className="w-px h-3.5 bg-cyan-500/20" />
                    {editingCount ? (
                      <input ref={countInputRef} type="number" min={1} value={countDraft}
                        onChange={(e) => setCountDraft(e.target.value)} onBlur={commitCount} onKeyDown={onCountKeyDown}
                        className="nodrag nopan w-10 h-full text-center text-[11px] font-bold bg-transparent text-cyan-400 outline-none" />
                    ) : (
                      <button onClick={startEditingCount}
                        className="nodrag nopan flex items-center justify-center px-2 h-full text-[12px] font-bold text-cyan-400 hover:bg-cyan-500/10 transition-colors"
                        title={t("workflow.editIterationCount", "Click to edit iteration count")}>
                        ×{iterationCount}
                      </button>
                    )}
                  </>
                )}
              </div>
            </TooltipTrigger>
            <TooltipContent side="bottom" className="max-w-[240px] text-xs">
              {iterationMode === "auto"
                ? t("workflow.iterationModeAutoTip", "Auto: iterations = longest array input. Click the mode to switch.")
                : t("workflow.iterationModeFixedTip", "Fixed: runs exactly ×N times. Click the mode to switch.")}
            </TooltipContent>
          </Tooltip>
        </div>

        {/* ── Expose-param pickers — rendered via portal ── */}
        {showInputPicker && createPortal(
          <PickerPortal nodeRef={nodeRef} side="left" offsetTop={TITLE_BAR_HEIGHT + 4}>
            <ExposeParamPicker iteratorId={id} direction="input" onClose={() => setShowInputPicker(false)} />
          </PickerPortal>,
          document.body,
        )}
        {showOutputPicker && createPortal(
          <PickerPortal nodeRef={nodeRef} side="right" offsetTop={TITLE_BAR_HEIGHT + 4}>
            <ExposeParamPicker iteratorId={id} direction="output" onClose={() => setShowOutputPicker(false)} />
          </PickerPortal>,
          document.body,
        )}

        {/* ── Running progress bar ───────────────────────────── */}
        {running && !collapsed && (
          <div className="px-3 py-1.5 bg-blue-500/5">
            <div className="flex items-center gap-2 mb-1">
              <svg className="animate-spin flex-shrink-0 text-blue-400" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                <circle cx="12" cy="12" r="10" strokeDasharray="60" strokeDashoffset="20" />
              </svg>
              <span className="text-[11px] text-blue-400 font-medium flex-1">{progress?.message || t("workflow.running", "Running...")}</span>
              {progress && <span className="text-[10px] text-blue-400/70">{Math.round(progress.progress)}%</span>}
            </div>
            <div className="h-1.5 rounded-full bg-blue-500/20 overflow-hidden">
              <div className="h-full bg-blue-500 transition-all duration-300 ease-out rounded-full" style={{ width: `${progress?.progress ?? 0}%` }} />
            </div>
          </div>
        )}

        {/* ── Error details + Retry ──────────────────────────── */}
        {status === "error" && errorMessage && !collapsed && (
          <div className="px-3 py-1.5 bg-red-500/5">
            <div className="flex items-start gap-1.5 p-2 rounded-lg bg-red-500/10 border border-red-500/20">
              <span className="text-red-400 text-[10px] mt-0.5 flex-shrink-0">⚠</span>
              <span className="text-[10px] text-red-400/90 leading-tight line-clamp-3 break-words flex-1" title={errorMessage}>{errorMessage}</span>
              <button onClick={(e) => { e.stopPropagation(); if (workflowId) retryNode(workflowId, id); }}
                className="text-[10px] text-red-400 font-medium hover:text-red-300 transition-colors flex items-center gap-1 flex-shrink-0 ml-1" title={t("workflow.retry", "Retry")}>
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <polyline points="23 4 23 10 17 10" /><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
                </svg>
                {t("workflow.retry", "Retry")}
              </button>
            </div>
          </div>
        )}

        {/* ── Body: Internal canvas area (full width, no port strips) ── */}
        {!collapsed && (
          <div className="relative" style={{ height: effectiveHeight - TITLE_BAR_HEIGHT }}>
            {/* Empty state */}
            {!hasChildren && (
              <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none pb-12">
                <div className="flex flex-col items-center gap-3 opacity-40">
                  <span className="text-[11px] text-muted-foreground">{t("workflow.iteratorEmpty", "No child nodes yet")}</span>
                  <svg width="20" height="32" viewBox="0 0 20 32" fill="none" className="text-cyan-500/60">
                    <path d="M10 0 L10 24 M4 18 L10 26 L16 18" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </div>
              </div>
            )}

            {/* ── Add Node button — positioned at bottom center inside the container ── */}
            <div
              className="absolute left-1/2 -translate-x-1/2 z-[60]"
              style={{ bottom: 10 }}
              onMouseDown={(e) => e.stopPropagation()}
            >
              <button
                onClick={handleAddNodeInside}
                className="nodrag nopan flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[10px] font-medium
                  bg-cyan-500/10 text-cyan-400 border border-cyan-500/20
                  hover:bg-cyan-500/20 hover:border-cyan-500/40 transition-all cursor-pointer shadow-sm backdrop-blur-sm"
                title={t("workflow.addNodeInside", "Add node inside Iterator")}
              >
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
                  <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
                </svg>
                {t("workflow.addNode", "Add Node")}
              </button>
            </div>
          </div>
        )}

        {/* Collapsed child count */}
        {collapsed && hasChildren && (
          <div className="px-3 py-1 text-[10px] text-muted-foreground/60">
            {t("workflow.childNodesCount", "{{count}} child node(s)", { count: childNodeIds.length })}
          </div>
        )}

        {/* ── Resize handles ─────────────────────────────────── */}
        {selected && !collapsed && (
          <>
            <div onMouseDown={(e) => onEdgeResizeStart(e, 1, 0)} className="nodrag absolute top-2 right-0 bottom-2 w-[5px] cursor-ew-resize z-20 hover:bg-cyan-500/20" />
            <div onMouseDown={(e) => onEdgeResizeStart(e, -1, 0)} className="nodrag absolute top-2 left-0 bottom-2 w-[5px] cursor-ew-resize z-20 hover:bg-cyan-500/20" />
            <div onMouseDown={(e) => onEdgeResizeStart(e, 0, 1)} className="nodrag absolute bottom-0 left-2 right-2 h-[5px] cursor-ns-resize z-20 hover:bg-cyan-500/20" />
            <div onMouseDown={(e) => onEdgeResizeStart(e, 0, -1)} className="nodrag absolute top-0 left-2 right-2 h-[5px] cursor-ns-resize z-20 hover:bg-cyan-500/20" />
            <div onMouseDown={(e) => onEdgeResizeStart(e, 1, 1)} className="nodrag absolute bottom-0 right-0 w-3 h-3 cursor-se-resize z-30" />
            <div onMouseDown={(e) => onEdgeResizeStart(e, -1, 1)} className="nodrag absolute bottom-0 left-0 w-3 h-3 cursor-sw-resize z-30" />
            <div onMouseDown={(e) => onEdgeResizeStart(e, 1, -1)} className="nodrag absolute top-0 right-0 w-3 h-3 cursor-ne-resize z-30" />
            <div onMouseDown={(e) => onEdgeResizeStart(e, -1, -1)} className="nodrag absolute top-0 left-0 w-3 h-3 cursor-nw-resize z-30" />
          </>
        )}
      </div>

      {/* ── LEFT SIDE: exposed input capsules ──────────────────── */}
      {!collapsed && inputDefs.map((port, i) => {
        const top = getCapsuleTop(i);
        const extHandleId = `input-${port.key}`;
        const intHandleId = `input-inner-${port.key}`;
        const extConnected = isHandleConnected(extHandleId, "target");
        const intConnected = isHandleConnected(intHandleId, "source");
        const ep = exposedParamMap.get(port.key);
        const tooltipText = ep
          ? `${ep.paramKey.split("_").map((w: string) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ")} — ${ep.subNodeLabel}`
          : port.label;
        return (
          <React.Fragment key={`cap-in-${port.key}`}>
            {/* External target handle — on the left border */}
            <Handle
              type="target"
              position={Position.Left}
              id={extHandleId}
              style={{
                ...dotStyle(extConnected),
                position: "absolute",
                top: top + CAPSULE_HEIGHT / 2,
                left: -HANDLE_DOT / 2,
                transform: "translateY(-50%)",
              }}
            />
            {/* Capsule label between the two dots */}
            <Tooltip delayDuration={200}>
              <TooltipTrigger asChild>
                <div
                  className="absolute pointer-events-auto flex items-center"
                  style={{
                    top: top,
                    left: HANDLE_DOT,
                    width: CAPSULE_LABEL_WIDTH,
                    height: CAPSULE_HEIGHT,
                    zIndex: 45,
                  }}
                >
                  <div className="rounded-full bg-[hsl(var(--card))] border border-cyan-500/40 px-2.5 flex items-center w-full"
                    style={{ height: CAPSULE_HEIGHT - 4 }}>
                    <span className="text-[11px] text-foreground font-medium whitespace-nowrap select-none truncate">
                      {port.label}
                    </span>
                  </div>
                </div>
              </TooltipTrigger>
              <TooltipContent side="bottom" className="text-xs">
                {tooltipText}
              </TooltipContent>
            </Tooltip>
            {/* Internal source handle — right side of capsule label area */}
            <Handle
              type="source"
              position={Position.Right}
              id={intHandleId}
              style={{
                ...dotStyle(intConnected),
                position: "absolute",
                top: top + CAPSULE_HEIGHT / 2,
                left: HANDLE_DOT + CAPSULE_LABEL_WIDTH + 4,
                transform: "translateY(-50%)",
              }}
            />
          </React.Fragment>
        );
      })}

      {/* ── RIGHT SIDE: exposed output capsules ──────────────────── */}
      {!collapsed && outputDefs.map((port, i) => {
        const top = getCapsuleTop(i);
        const intHandleId = `output-inner-${port.key}`;
        const extHandleId = `output-${port.key}`;
        const extConnected = isHandleConnected(extHandleId, "source");
        const intConnected = isHandleConnected(intHandleId, "target");
        const ep = exposedParamMap.get(port.key);
        const tooltipText = ep
          ? `${ep.paramKey.split("_").map((w: string) => w.charAt(0).toUpperCase() + w.slice(1)).join(" ")} — ${ep.subNodeLabel}`
          : port.label;
        // Compute left-based positions so ReactFlow handle lookup is reliable
        const capsuleLabelLeft = effectiveWidth - HANDLE_DOT - CAPSULE_LABEL_WIDTH;
        const intHandleLeft = capsuleLabelLeft - HANDLE_DOT - 4;
        const extHandleLeft = effectiveWidth - HANDLE_DOT / 2;
        return (
          <React.Fragment key={`cap-out-${port.key}`}>
            {/* Internal target handle — left side of capsule */}
            <Handle
              type="target"
              position={Position.Left}
              id={intHandleId}
              style={{
                ...dotStyle(intConnected),
                position: "absolute",
                top: top + CAPSULE_HEIGHT / 2,
                left: intHandleLeft,
                transform: "translateY(-50%)",
              }}
            />
            {/* Capsule label */}
            <Tooltip delayDuration={200}>
              <TooltipTrigger asChild>
                <div
                  className="absolute pointer-events-auto flex items-center justify-end"
                  style={{
                    top: top,
                    left: capsuleLabelLeft,
                    width: CAPSULE_LABEL_WIDTH,
                    height: CAPSULE_HEIGHT,
                    zIndex: 45,
                  }}
                >
                  <div className="rounded-full bg-[hsl(var(--card))] border border-cyan-500/40 px-2.5 flex items-center justify-end w-full"
                    style={{ height: CAPSULE_HEIGHT - 4 }}>
                    <span className="text-[11px] text-foreground font-medium whitespace-nowrap select-none truncate text-right">
                      {port.label}
                    </span>
                  </div>
                </div>
              </TooltipTrigger>
              <TooltipContent side="bottom" className="text-xs">
                {tooltipText}
              </TooltipContent>
            </Tooltip>
            {/* External source handle — on the right border */}
            <Handle
              type="source"
              position={Position.Right}
              id={extHandleId}
              style={{
                ...dotStyle(extConnected),
                position: "absolute",
                top: top + CAPSULE_HEIGHT / 2,
                left: extHandleLeft,
                transform: "translateY(-50%)",
              }}
            />
          </React.Fragment>
        );
      })}

      {/* ── External "+" button — right side ── */}
      {(hovered || selected) && (
        <Tooltip delayDuration={0}>
          <TooltipTrigger asChild>
            <button
              type="button"
              className="nodrag nopan absolute top-1/2 -translate-y-1/2 -right-3 z-40 flex items-center justify-center w-6 h-6 rounded-full shadow-lg backdrop-blur-sm bg-cyan-500 text-white hover:bg-cyan-600 hover:scale-110 transition-all duration-150"
              onClick={(e) => {
                e.stopPropagation();
                const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
                window.dispatchEvent(
                  new CustomEvent("workflow:open-add-node-menu", {
                    detail: { x: rect.right, y: rect.top + rect.height / 2, sourceNodeId: id, side: "right" },
                  }),
                );
              }}
            >
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
                <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
              </svg>
            </button>
          </TooltipTrigger>
          <TooltipContent side="right">
            {t("workflow.addNode", "Add Node")}
          </TooltipContent>
        </Tooltip>
      )}
    </div>
  );
}

export default memo(IteratorNodeContainerComponent);
export { MIN_ITERATOR_WIDTH, MIN_ITERATOR_HEIGHT, CHILD_PADDING };
