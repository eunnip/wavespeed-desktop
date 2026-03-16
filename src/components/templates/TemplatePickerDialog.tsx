/**
 * TemplatePickerDialog — modal dialog for browsing templates.
 * Simple list view matching TemplatesPage style, no category sidebar.
 */
import { useState, useEffect, useCallback, useMemo } from "react";
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
} from "lucide-react";
import type { Template } from "@/types/template";

interface TemplatePickerDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  templateType: "playground" | "workflow";
  onUseTemplate: (template: Template, mode?: "new" | "replace") => void;
}

export function TemplatePickerDialog({
  open,
  onOpenChange,
  templateType,
  onUseTemplate,
}: TemplatePickerDialogProps) {
  const { t } = useTranslation();
  const { loadTemplates, updateTemplate, deleteTemplate, exportTemplates } =
    useTemplateStore();
  const [editingTemplate, setEditingTemplate] = useState<Template | null>(null);
  const [deletingTemplate, setDeletingTemplate] = useState<Template | null>(
    null,
  );
  const [searchQuery, setSearchQuery] = useState("");
  const [localTemplates, setLocalTemplates] = useState<Template[]>([]);

  // Load templates when dialog opens
  useEffect(() => {
    if (!open) return;
    setSearchQuery("");
    let cancelled = false;
    loadTemplates({ templateType }).then(() => {
      if (!cancelled) {
        setLocalTemplates(useTemplateStore.getState().templates);
      }
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, templateType]);

  const filteredTemplates = useMemo(() => {
    if (!searchQuery.trim()) return localTemplates;
    const q = searchQuery.trim().toLowerCase();
    return localTemplates.filter((tpl) => {
      const i18nName = tpl.i18nKey
        ? t(`presetTemplates.${tpl.i18nKey}.name`, { defaultValue: "" })
        : "";
      const i18nDesc = tpl.i18nKey
        ? t(`presetTemplates.${tpl.i18nKey}.description`, { defaultValue: "" })
        : "";
      return (
        tpl.name.toLowerCase().includes(q) ||
        (tpl.description ?? "").toLowerCase().includes(q) ||
        (tpl.tags ?? []).some((tag) => tag.toLowerCase().includes(q)) ||
        (tpl.playgroundData?.modelId ?? "").toLowerCase().includes(q) ||
        (tpl.playgroundData?.modelName ?? "").toLowerCase().includes(q) ||
        (tpl.workflowData?.category ?? "").toLowerCase().includes(q) ||
        (tpl._searchText ?? "").toLowerCase().includes(q) ||
        i18nName.toLowerCase().includes(q) ||
        i18nDesc.toLowerCase().includes(q)
      );
    });
  }, [localTemplates, searchQuery, t]);

  const reload = useCallback(() => {
    loadTemplates({ templateType }).then(() => {
      setLocalTemplates(useTemplateStore.getState().templates);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [templateType]);

  const handleUse = useCallback(
    (template: Template) => {
      onUseTemplate(template);
      onOpenChange(false);
    },
    [onUseTemplate, onOpenChange],
  );

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
        reload();
      } catch (error) {
        toast({
          title: t("common.error"),
          description: (error as Error).message,
          variant: "destructive",
        });
      }
    },
    [editingTemplate, updateTemplate, t, reload],
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
      reload();
    } catch (error) {
      toast({
        title: t("common.error"),
        description: (error as Error).message,
        variant: "destructive",
      });
    }
  }, [deletingTemplate, deleteTemplate, t, reload]);

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

  // Close on Escape key
  useEffect(() => {
    if (!open) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        onOpenChange(false);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, onOpenChange]);

  const formatDate = (dateStr: string) => {
    const d = new Date(dateStr);
    return `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, "0")}/${String(d.getDate()).padStart(2, "0")}`;
  };

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/60"
      onClick={() => onOpenChange(false)}
    >
      <div
        className="w-[70vw] max-w-[800px] h-[70vh] rounded-xl border border-border bg-card shadow-2xl flex flex-col overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3 border-b border-border">
          <h2 className="text-base font-semibold">{t("templates.title")}</h2>
          <button
            onClick={() => onOpenChange(false)}
            className="text-muted-foreground hover:text-foreground transition-colors text-sm px-2 py-1"
          >
            ✕
          </button>
        </div>

        {/* Search */}
        <div className="px-5 py-3 border-b border-border/50">
          <div className="relative max-w-sm">
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
        <div className="flex-1 overflow-y-auto px-5 py-3">
          {filteredTemplates.length === 0 && (
            <div className="flex flex-col items-center justify-center h-40 text-muted-foreground">
              <FolderOpen className="h-10 w-10 mb-2 opacity-40" />
              <p className="text-sm">{t("templates.noTemplates")}</p>
            </div>
          )}

          {filteredTemplates.map((tpl) => {
            const displayName = tpl.i18nKey
              ? t(`presetTemplates.${tpl.i18nKey}.name`, {
                  defaultValue: tpl.name,
                })
              : tpl.name;
            const isCustom = tpl.type === "custom";
            return (
              <div
                key={tpl.id}
                className="flex items-center gap-3 mb-2 px-3 py-2.5 rounded-md border border-border/30 hover:bg-accent/30 transition-colors"
              >
                <div className="flex-1 min-w-0">
                  <span className="text-sm font-medium truncate block">
                    {displayName}
                  </span>
                  <span className="text-xs text-muted-foreground">
                    {t("templates.lastUpdated")}: {formatDate(tpl.updatedAt)}
                  </span>
                </div>
                <div className="flex items-center gap-1.5 flex-shrink-0">
                  <button
                    onClick={() => handleUse(tpl)}
                    className="h-7 px-3 rounded-md text-xs font-medium bg-primary text-primary-foreground hover:bg-primary/90 transition-colors flex items-center gap-1"
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
                      <Pencil className="h-4 w-4" />
                    </button>
                  )}
                  <button
                    onClick={() => handleExport(tpl)}
                    className="p-1.5 rounded-md text-muted-foreground hover:text-foreground hover:bg-accent transition-colors"
                    title={t("templates.export")}
                  >
                    <Download className="h-4 w-4" />
                  </button>
                  {isCustom && (
                    <button
                      onClick={() => setDeletingTemplate(tpl)}
                      className="p-1.5 rounded-md text-destructive/70 hover:text-destructive hover:bg-destructive/10 transition-colors"
                      title={t("common.delete")}
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
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
          className="fixed inset-0 z-[10000] flex items-center justify-center bg-black/60"
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
