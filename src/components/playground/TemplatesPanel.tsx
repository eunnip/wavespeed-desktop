import { useCallback, useState, useEffect, useMemo } from "react";
import { useTranslation } from "react-i18next";
import {
  TemplateDialog,
  type TemplateFormData,
} from "@/components/templates/TemplateDialog";
import { useTemplateStore } from "@/stores/templateStore";
import { toast } from "@/hooks/useToast";
import {
  Search,
  Play,
  Pencil,
  Trash2,
  Download,
  FolderOpen,
  ChevronRight,
  ChevronDown,
} from "lucide-react";
import type { Template } from "@/types/template";

interface TemplatesPanelProps {
  onUseTemplate: (template: Template, mode?: "new" | "replace") => void;
}

export function TemplatesPanel({ onUseTemplate }: TemplatesPanelProps) {
  const { t } = useTranslation();
  const { loadTemplates, updateTemplate, deleteTemplate, exportTemplates } =
    useTemplateStore();
  const [editingTemplate, setEditingTemplate] = useState<Template | null>(null);
  const [deletingTemplate, setDeletingTemplate] = useState<Template | null>(
    null,
  );
  const [searchQuery, setSearchQuery] = useState("");
  const [collapsedGroups, setCollapsedGroups] = useState<Set<string>>(
    new Set(),
  );

  const [localTemplates, setLocalTemplates] = useState<Template[]>([]);
  const [loadCounter, setLoadCounter] = useState(0);
  const reloadTemplates = () => setLoadCounter((c) => c + 1);

  useEffect(() => {
    let cancelled = false;
    loadTemplates({ templateType: "playground" }).then(() => {
      if (!cancelled) {
        setLocalTemplates(useTemplateStore.getState().templates);
      }
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loadCounter]);

  // Local search filtering (supports modelId, modelName, name, i18n)
  const filteredTemplates = useMemo(() => {
    if (!searchQuery.trim()) return localTemplates;
    const q = searchQuery.trim().toLowerCase();
    return localTemplates.filter((tpl) => {
      const i18nName = tpl.i18nKey
        ? t(`presetTemplates.${tpl.i18nKey}.name`, { defaultValue: "" })
        : "";
      return (
        tpl.name.toLowerCase().includes(q) ||
        (tpl.description ?? "").toLowerCase().includes(q) ||
        (tpl.tags ?? []).some((tag) => tag.toLowerCase().includes(q)) ||
        (tpl.playgroundData?.modelId ?? "").toLowerCase().includes(q) ||
        (tpl.playgroundData?.modelName ?? "").toLowerCase().includes(q) ||
        (tpl._searchText ?? "").toLowerCase().includes(q) ||
        i18nName.toLowerCase().includes(q)
      );
    });
  }, [localTemplates, searchQuery, t]);

  const grouped = useMemo(() => {
    const groups: Record<string, Template[]> = {};
    for (const tpl of filteredTemplates) {
      const key = tpl.playgroundData?.modelId || "other";
      if (!groups[key]) groups[key] = [];
      groups[key].push(tpl);
    }
    return Object.entries(groups).sort(([a], [b]) => a.localeCompare(b));
  }, [filteredTemplates]);

  const toggleGroup = (groupKey: string) => {
    setCollapsedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(groupKey)) next.delete(groupKey);
      else next.add(groupKey);
      return next;
    });
  };

  const handleSaveEdit = useCallback(
    async (data: TemplateFormData) => {
      if (!editingTemplate) return;
      try {
        await updateTemplate(editingTemplate.id, { name: data.name });
        toast({
          title: t("templates.templateUpdated"),
          description: t("templates.updatedSuccessfully", { name: data.name }),
        });
        setEditingTemplate(null);
        reloadTemplates();
      } catch (error) {
        toast({
          title: t("common.error"),
          description: (error as Error).message,
          variant: "destructive",
        });
      }
    },
    [editingTemplate, updateTemplate, t],
  );

  const handleDeleteConfirm = useCallback(async () => {
    if (!deletingTemplate) return;
    try {
      await deleteTemplate(deletingTemplate.id);
      toast({
        title: t("templates.templateDeleted"),
        description: t("templates.deletedSuccessfully", {
          name: deletingTemplate.name,
        }),
      });
      setDeletingTemplate(null);
      reloadTemplates();
    } catch (error) {
      toast({
        title: t("common.error"),
        description: (error as Error).message,
        variant: "destructive",
      });
    }
  }, [deletingTemplate, deleteTemplate, t]);

  const handleExport = useCallback(
    async (template: Template) => {
      try {
        await exportTemplates([template.id]);
        toast({
          title: t("templates.templateExported"),
          description: t("templates.exportedSuccessfully", {
            name: template.name,
          }),
        });
      } catch (error) {
        toast({
          title: t("common.error"),
          description: (error as Error).message,
          variant: "destructive",
        });
      }
    },
    [exportTemplates, t],
  );

  const formatDate = (dateStr: string) => {
    const d = new Date(dateStr);
    return `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, "0")}/${String(d.getDate()).padStart(2, "0")}`;
  };

  return (
    <div className="flex flex-col h-full">
      {/* Search */}
      <div className="px-4 py-3 border-b border-border/50">
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder={t("templates.searchPlaceholder")}
            className="w-full pl-8 pr-3 py-1.5 text-sm rounded-md border border-border bg-background focus:outline-none focus:ring-1 focus:ring-primary/50"
          />
        </div>
      </div>

      {/* Template List */}
      <div className="flex-1 overflow-y-auto">
        {filteredTemplates.length === 0 && (
          <div className="flex flex-col items-center justify-center h-40 text-muted-foreground">
            <FolderOpen className="h-10 w-10 mb-2 opacity-40" />
            <p className="text-xs">{t("templates.noTemplates")}</p>
          </div>
        )}

        {grouped.map(([groupKey, groupTemplates]) => {
          const isCollapsed = collapsedGroups.has(groupKey);
          return (
            <div
              key={groupKey}
              className="mx-3 mt-3 rounded-lg border border-border/50 overflow-hidden"
            >
              {/* Group Header */}
              <button
                onClick={() => toggleGroup(groupKey)}
                className="w-full flex items-center gap-2 px-3 py-2.5 text-sm font-semibold hover:bg-muted/30 transition-colors"
              >
                {isCollapsed ? (
                  <ChevronRight className="h-3.5 w-3.5 text-muted-foreground" />
                ) : (
                  <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />
                )}
                <span className="truncate">{groupKey}</span>
              </button>
              <div className="px-3 pb-1.5 -mt-1 text-xs text-muted-foreground">
                {t("templates.templateCount", {
                  count: groupTemplates.length,
                })}
              </div>

              {/* Template Rows */}
              {!isCollapsed &&
                groupTemplates.map((tpl) => {
                  const displayName = tpl.i18nKey
                    ? t(`presetTemplates.${tpl.i18nKey}.name`, {
                        defaultValue: tpl.name,
                      })
                    : tpl.name;
                  const isCustom = tpl.type === "custom";
                  return (
                    <div
                      key={tpl.id}
                      className="flex items-center gap-2 mx-2 mb-1.5 px-2.5 py-2 rounded-md border border-border/30 hover:bg-accent/30 transition-colors"
                    >
                      <div className="flex-1 min-w-0">
                        <span className="text-sm font-medium truncate block">
                          {displayName}
                        </span>
                        <span className="text-xs text-muted-foreground">
                          {t("templates.lastUpdated")}:{" "}
                          {formatDate(tpl.updatedAt)}
                        </span>
                      </div>
                      <div className="flex items-center gap-1 flex-shrink-0">
                        <button
                          onClick={() => onUseTemplate(tpl)}
                          className="h-7 px-2.5 rounded-md text-xs font-medium bg-primary text-primary-foreground hover:bg-primary/90 transition-colors flex items-center gap-1"
                        >
                          <Play className="h-3 w-3" />
                          {t("templates.use")}
                        </button>
                        {isCustom && (
                          <button
                            onClick={() => setEditingTemplate(tpl)}
                            className="p-1.5 rounded-md text-muted-foreground hover:text-foreground hover:bg-accent transition-colors"
                            title={t("common.edit")}
                          >
                            <Pencil className="h-3.5 w-3.5" />
                          </button>
                        )}
                        <button
                          onClick={() => handleExport(tpl)}
                          className="p-1.5 rounded-md text-muted-foreground hover:text-foreground hover:bg-accent transition-colors"
                          title={t("templates.export")}
                        >
                          <Download className="h-3.5 w-3.5" />
                        </button>
                        {isCustom && (
                          <button
                            onClick={() => setDeletingTemplate(tpl)}
                            className="p-1.5 rounded-md text-destructive/70 hover:text-destructive hover:bg-destructive/10 transition-colors"
                            title={t("common.delete")}
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
            </div>
          );
        })}
      </div>

      {/* Edit Dialog */}
      <TemplateDialog
        open={!!editingTemplate}
        onOpenChange={(o) => !o && setEditingTemplate(null)}
        template={editingTemplate}
        onSave={handleSaveEdit}
        mode="edit"
      />

      {/* Delete Confirmation */}
      {deletingTemplate && (
        <div
          className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/60"
          onClick={() => setDeletingTemplate(null)}
        >
          <div
            className="w-[340px] rounded-xl border border-border bg-card p-5 shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-sm font-semibold mb-1">
              {t("templates.deleteTemplate")}
            </h3>
            <p className="text-xs text-muted-foreground mb-4">
              {t("templates.deleteConfirm", { name: deletingTemplate.name })}
            </p>
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setDeletingTemplate(null)}
                className="px-3 py-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors"
              >
                {t("common.cancel")}
              </button>
              <button
                onClick={handleDeleteConfirm}
                className="px-4 py-1.5 rounded-md text-xs font-medium bg-red-500 text-white hover:bg-red-600 transition-colors"
              >
                {t("common.delete")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
