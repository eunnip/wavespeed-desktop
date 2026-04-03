type MultipartFile = {
  filename: string;
  mimeType: string;
  data: Buffer;
};

export function parseMultipartFile(
  contentType: string | undefined,
  body: Buffer,
): MultipartFile | null {
  const boundaryMatch = contentType?.match(/boundary=(.+)$/i);
  if (!boundaryMatch) {
    return null;
  }
  const boundary = `--${boundaryMatch[1]}`;
  const parts = body.toString("binary").split(boundary);

  for (const part of parts) {
    if (!part.includes('name="file"')) {
      continue;
    }
    const headerEnd = part.indexOf("\r\n\r\n");
    if (headerEnd === -1) {
      continue;
    }
    const rawHeaders = part.slice(0, headerEnd);
    const rawData = part.slice(headerEnd + 4);
    const dispositionMatch = rawHeaders.match(/filename="([^"]+)"/i);
    const typeMatch = rawHeaders.match(/content-type:\s*([^\r\n]+)/i);
    const cleanedData = rawData.replace(/\r\n--$/, "").replace(/\r\n$/, "");

    return {
      filename: dispositionMatch?.[1] ?? "upload.bin",
      mimeType: typeMatch?.[1]?.trim() ?? "application/octet-stream",
      data: Buffer.from(cleanedData, "binary"),
    };
  }

  return null;
}
