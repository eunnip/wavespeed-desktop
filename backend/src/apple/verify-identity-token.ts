import crypto from "node:crypto";

type AppleIdentityTokenHeader = {
  alg?: string;
  kid?: string;
};

type AppleIdentityTokenClaims = {
  iss?: string;
  aud?: string | string[];
  exp?: number;
  sub?: string;
  nonce?: string;
  email?: string;
  email_verified?: string | boolean;
  is_private_email?: string | boolean;
};

export type AppleIdentity = {
  subject: string;
  email?: string;
  emailVerified?: boolean;
  isPrivateEmail?: boolean;
};

type VerifyAppleIdentityTokenOptions = {
  identityToken: string;
  expectedIssuer: string;
  expectedAudience?: string;
  rawNonce?: string;
  requireNonce?: boolean;
};

type AppleJwkSet = {
  keys?: JsonWebKey[];
};

const encoder = new TextEncoder();
const appleJwksURL = "https://appleid.apple.com/auth/keys";

let cachedKeys: Map<string, JsonWebKey> | undefined;
let cachedKeysExpiresAt = 0;

function decodeBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  return Uint8Array.from(Buffer.from(`${normalized}${padding}`, "base64"));
}

function parseJsonPart<T>(value: string): T {
  return JSON.parse(Buffer.from(decodeBase64Url(value)).toString("utf8")) as T;
}

function toBoolean(value: string | boolean | undefined): boolean | undefined {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    return value.toLowerCase() === "true";
  }
  return undefined;
}

function normalizeAudience(value: string | string[] | undefined): string[] {
  if (!value) {
    return [];
  }
  return Array.isArray(value) ? value : [value];
}

function sha256Hex(value: string): string {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function nonceMatches(claim: string | undefined, rawNonce: string | undefined): boolean {
  if (!claim || !rawNonce) {
    return false;
  }
  return claim === rawNonce || claim === sha256Hex(rawNonce);
}

async function getAppleJwk(kid: string): Promise<JsonWebKey | undefined> {
  if (!cachedKeys || Date.now() >= cachedKeysExpiresAt) {
    const response = await fetch(appleJwksURL, {
      headers: { accept: "application/json" },
    });
    if (!response.ok) {
      throw new Error(`Apple JWKS fetch failed with status ${response.status}`);
    }
    const body = (await response.json()) as AppleJwkSet;
    cachedKeys = new Map(
      (body.keys ?? [])
        .filter((candidate) => typeof candidate.kid === "string")
        .map((candidate) => [candidate.kid as string, candidate]),
    );
    cachedKeysExpiresAt = Date.now() + 60 * 60 * 1000;
  }
  return cachedKeys.get(kid);
}

export async function verifyAppleIdentityToken(
  options: VerifyAppleIdentityTokenOptions,
): Promise<AppleIdentity> {
  const parts = options.identityToken.split(".");
  if (parts.length !== 3) {
    throw new Error("Apple identity token must be a compact JWS");
  }

  const header = parseJsonPart<AppleIdentityTokenHeader>(parts[0]);
  const claims = parseJsonPart<AppleIdentityTokenClaims>(parts[1]);
  if (header.alg !== "ES256" || !header.kid) {
    throw new Error("Apple identity token header is invalid");
  }

  const jwk = await getAppleJwk(header.kid);
  if (!jwk) {
    throw new Error("Apple signing key was not found");
  }

  const key = await crypto.webcrypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );

  const verified = await crypto.webcrypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    decodeBase64Url(parts[2]),
    encoder.encode(`${parts[0]}.${parts[1]}`),
  );

  if (!verified) {
    throw new Error("Apple identity token signature verification failed");
  }
  if (claims.iss !== options.expectedIssuer) {
    throw new Error("Apple identity token issuer is invalid");
  }
  if (options.expectedAudience) {
    const audiences = normalizeAudience(claims.aud);
    if (!audiences.includes(options.expectedAudience)) {
      throw new Error("Apple identity token audience is invalid");
    }
  }
  if (!claims.sub) {
    throw new Error("Apple identity token subject is missing");
  }
  if (!claims.exp || claims.exp * 1000 <= Date.now()) {
    throw new Error("Apple identity token has expired");
  }
  if (options.requireNonce && !nonceMatches(claims.nonce, options.rawNonce)) {
    throw new Error("Apple identity token nonce is invalid");
  }

  return {
    subject: claims.sub,
    email: claims.email,
    emailVerified: toBoolean(claims.email_verified),
    isPrivateEmail: toBoolean(claims.is_private_email),
  };
}
