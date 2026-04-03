export type CatalogModelRecord = {
  id: string;
  name: string;
  summary: string;
  kind: string;
  thumbnailUrl?: string;
  requiresImageInput?: boolean;
};

export const defaultCatalogModels: CatalogModelRecord[] = [
  {
    id: "flux-pro",
    name: "Flux Pro",
    summary: "High-quality text-to-image generation for polished final outputs.",
    kind: "image",
  },
  {
    id: "seedream-4",
    name: "SeeDream 4",
    summary: "Fast image ideation with good prompt adherence.",
    kind: "image",
  },
  {
    id: "wan-2.2",
    name: "Wan 2.2",
    summary: "Text-to-video generation for short motion clips.",
    kind: "video",
  },
];
