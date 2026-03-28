import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

export type StoredObject = {
  body: Uint8Array;
  contentType?: string | null;
};

export interface ObjectStorage {
  putObject(key: string, body: Uint8Array, contentType: string): Promise<void>;
  getObject(key: string): Promise<StoredObject | undefined>;
}

type R2Config = {
  accountId: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  endpoint?: string;
};

export class LocalObjectStorage implements ObjectStorage {
  private readonly rootDir: string;

  constructor(rootDir: string) {
    this.rootDir = rootDir;
    fs.mkdirSync(rootDir, { recursive: true });
  }

  async putObject(key: string, body: Uint8Array): Promise<void> {
    const fullPath = path.resolve(this.rootDir, key);
    fs.mkdirSync(path.dirname(fullPath), { recursive: true });
    fs.writeFileSync(fullPath, body);
  }

  async getObject(key: string): Promise<StoredObject | undefined> {
    const fullPath = path.resolve(this.rootDir, key);
    if (!fs.existsSync(fullPath)) {
      return undefined;
    }
    return { body: fs.readFileSync(fullPath) };
  }
}

export class R2ObjectStorage implements ObjectStorage {
  private readonly bucket: string;
  private readonly host: string;
  private readonly endpoint: string;
  private readonly config: R2Config;

  constructor(config: R2Config) {
    this.config = config;
    this.bucket = config.bucket;
    this.host = config.endpoint
      ? new URL(config.endpoint).host
      : `${config.accountId}.r2.cloudflarestorage.com`;
    this.endpoint = config.endpoint?.replace(/\/$/, "") ?? `https://${this.host}`;
  }

  async putObject(key: string, body: Uint8Array, contentType: string): Promise<void> {
    const response = await this.signedFetch("PUT", key, body, contentType);
    if (!response.ok) {
      throw new Error(`R2 putObject failed: ${response.status}`);
    }
  }

  async getObject(key: string): Promise<StoredObject | undefined> {
    const response = await this.signedFetch("GET", key);
    if (response.status === 404) {
      return undefined;
    }
    if (!response.ok) {
      throw new Error(`R2 getObject failed: ${response.status}`);
    }
    return {
      body: new Uint8Array(await response.arrayBuffer()),
      contentType: response.headers.get("content-type"),
    };
  }

  private async signedFetch(
    method: "GET" | "PUT",
    key: string,
    body?: Uint8Array,
    contentType?: string,
  ): Promise<Response> {
    const now = new Date();
    const amzDate = this.toAmzDate(now);
    const dateStamp = this.toDateStamp(now);
    const canonicalUri = `/${this.bucket}/${this.encodeKey(key)}`;
    const payloadHash = this.sha256Hex(body ?? new Uint8Array());
    const url = `${this.endpoint}${canonicalUri}`;

    const headers = new Headers({
      host: this.host,
      "x-amz-content-sha256": payloadHash,
      "x-amz-date": amzDate,
    });
    if (contentType) {
      headers.set("content-type", contentType);
    }

    const signedHeaders = [...headers.keys()]
      .map((header) => header.toLowerCase())
      .sort()
      .join(";");

    const canonicalHeaders = [...headers.entries()]
      .map(([name, value]) => [name.toLowerCase(), value.trim()] as const)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([name, value]) => `${name}:${value}\n`)
      .join("");

    const canonicalRequest = [
      method,
      canonicalUri,
      "",
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join("\n");

    const credentialScope = `${dateStamp}/auto/s3/aws4_request`;
    const stringToSign = [
      "AWS4-HMAC-SHA256",
      amzDate,
      credentialScope,
      this.sha256Hex(new TextEncoder().encode(canonicalRequest)),
    ].join("\n");

    const signingKey = this.getSignatureKey(dateStamp);
    const signature = crypto.createHmac("sha256", signingKey).update(stringToSign).digest("hex");

    headers.set(
      "Authorization",
      [
        `AWS4-HMAC-SHA256 Credential=${this.config.accessKeyId}/${credentialScope}`,
        `SignedHeaders=${signedHeaders}`,
        `Signature=${signature}`,
      ].join(", "),
    );

    return fetch(url, {
      method,
      headers,
      body: body ? Buffer.from(body) : undefined,
    });
  }

  private getSignatureKey(dateStamp: string): Buffer {
    const dateKey = crypto
      .createHmac("sha256", `AWS4${this.config.secretAccessKey}`)
      .update(dateStamp)
      .digest();
    const regionKey = crypto.createHmac("sha256", dateKey).update("auto").digest();
    const serviceKey = crypto.createHmac("sha256", regionKey).update("s3").digest();
    return crypto.createHmac("sha256", serviceKey).update("aws4_request").digest();
  }

  private sha256Hex(body: Uint8Array): string {
    return crypto.createHash("sha256").update(body).digest("hex");
  }

  private toAmzDate(date: Date): string {
    return date.toISOString().replace(/[:-]|\.\d{3}/g, "");
  }

  private toDateStamp(date: Date): string {
    return date.toISOString().slice(0, 10).replace(/-/g, "");
  }

  private encodeKey(key: string): string {
    return key
      .split("/")
      .map((segment) => encodeURIComponent(segment))
      .join("/");
  }
}
