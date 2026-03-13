/**
 * Directory Import node — scans a local directory for media files
 * and outputs an array of file URLs.
 *
 * Designed to feed into an Iterator (auto mode) for batch processing.
 * Output is always an array of local-asset:// URLs.
 */
import {
  BaseNodeHandler,
  type NodeExecutionContext,
  type NodeExecutionResult,
} from "../base";
import type { NodeTypeDefinition } from "../../../../src/workflow/types/node-defs";
import { readdirSync, statSync, existsSync } from "fs";
import { join, extname } from "path";

const MEDIA_EXTENSIONS: Record<string, string[]> = {
  image: [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tiff", ".tif", ".svg", ".avif"],
  video: [".mp4", ".webm", ".mov", ".avi", ".mkv", ".flv", ".wmv", ".m4v"],
  audio: [".mp3", ".wav", ".flac", ".m4a", ".ogg", ".aac", ".wma"],
  all: [], // populated at runtime from all above
};
MEDIA_EXTENSIONS.all = [
  ...MEDIA_EXTENSIONS.image,
  ...MEDIA_EXTENSIONS.video,
  ...MEDIA_EXTENSIONS.audio,
];

export const directoryImportDef: NodeTypeDefinition = {
  type: "input/directory-import",
  category: "input",
  label: "Directory",
  inputs: [],
  outputs: [{ key: "output", label: "Files", dataType: "any", required: true }],
  params: [
    {
      key: "directoryPath",
      label: "Directory",
      type: "string",
      dataType: "text",
      connectable: false,
      default: "",
    },
    {
      key: "mediaType",
      label: "File Type",
      type: "select",
      dataType: "text",
      connectable: false,
      default: "image",
      options: [
        { label: "Images", value: "image" },
        { label: "Videos", value: "video" },
        { label: "Audio", value: "audio" },
        { label: "All Media", value: "all" },
      ],
    },
  ],
};

export class DirectoryImportHandler extends BaseNodeHandler {
  constructor() {
    super(directoryImportDef);
  }

  async execute(ctx: NodeExecutionContext): Promise<NodeExecutionResult> {
    const start = Date.now();
    const dirPath = String(ctx.params.directoryPath ?? "").trim();
    const mediaType = String(ctx.params.mediaType ?? "image");

    if (!dirPath) {
      return {
        status: "error",
        outputs: {},
        durationMs: Date.now() - start,
        cost: 0,
        error: "No directory selected. Please choose a directory.",
      };
    }

    if (!existsSync(dirPath)) {
      return {
        status: "error",
        outputs: {},
        durationMs: Date.now() - start,
        cost: 0,
        error: `Directory not found: ${dirPath}`,
      };
    }

    const allowedExts = new Set(MEDIA_EXTENSIONS[mediaType] ?? MEDIA_EXTENSIONS.all);
    const files = scanDirectory(dirPath, allowedExts);
    files.sort(); // deterministic order

    // Convert to local-asset:// URLs
    const urls = files.map((f) => `local-asset://${encodeURIComponent(f)}`);

    ctx.onProgress(100, `Found ${urls.length} file(s)`);

    return {
      status: "success",
      outputs: { output: urls },
      resultPath: urls[0] ?? "",
      resultMetadata: {
        output: urls,
        resultUrl: urls[0] ?? "",
        resultUrls: urls,
        fileCount: urls.length,
        directory: dirPath,
        mediaType,
      },
      durationMs: Date.now() - start,
      cost: 0,
    };
  }
}

function scanDirectory(dir: string, allowedExts: Set<string>): string[] {
  const results: string[] = [];
  try {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.isFile()) {
        const ext = extname(entry.name).toLowerCase();
        if (allowedExts.has(ext)) {
          results.push(join(dir, entry.name));
        }
      }
    }
  } catch {
    // Skip unreadable directories
  }
  return results;
}
