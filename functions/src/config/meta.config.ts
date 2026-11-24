/**
 * PropMatch AI — Central Meta API Configuration
 *
 * Centralizes all Meta Graph API and Marketing API versioning, base URLs,
 * and lifecycle metadata in one place. Services across the backend import
 * version constants from this file rather than hardcoding version strings.
 *
 * Official Reference:
 * https://developers.facebook.com/docs/graph-api/changelog/versions/
 */

export interface MetaVersionMetadata {
  version: string;
  releaseDate: string;
  graphApiExpirationDate: string;
  marketingApiExpirationDate: string;
  status: 'LATEST' | 'ACTIVE_STABLE' | 'DEPRECATED' | 'SUNSET';
  notes: string;
}

/**
 * Official Meta API Version Schedule Table (2024–2026+)
 * Note: Graph API and Marketing API have separate lifecycles and deprecation policies.
 */
export const META_VERSION_SCHEDULE: Record<string, MetaVersionMetadata> = {
  "v27.0": {
    version: "v27.0",
    releaseDate: "2026-11-04",
    graphApiExpirationDate: "2028-11-04",
    marketingApiExpirationDate: "2028-11-04",
    status: "LATEST",
    notes: "Latest active major version for Graph API and Marketing API."
  },
  "v26.0": {
    version: "v26.0",
    releaseDate: "2026-07-29",
    graphApiExpirationDate: "2028-07-29",
    marketingApiExpirationDate: "2028-07-29",
    status: "ACTIVE_STABLE",
    notes: "Active stable release supported through mid-2028. Baseline version for PropMatch AI."
  },
  "v25.0": {
    version: "v25.0",
    releaseDate: "2026-02-18",
    graphApiExpirationDate: "2028-07-29",
    marketingApiExpirationDate: "2028-02-18",
    status: "ACTIVE_STABLE",
    notes: "Supported active release."
  },
  "v24.0": {
    version: "v24.0",
    releaseDate: "2025-10-08",
    graphApiExpirationDate: "2028-02-18",
    marketingApiExpirationDate: "2027-10-08",
    status: "ACTIVE_STABLE",
    notes: "Supported active release."
  },
  "v23.0": {
    version: "v23.0",
    releaseDate: "2025-05-29",
    graphApiExpirationDate: "2027-10-08",
    marketingApiExpirationDate: "2027-05-29",
    status: "ACTIVE_STABLE",
    notes: "Supported active release."
  },
  "v22.0": {
    version: "v22.0",
    releaseDate: "2025-01-21",
    graphApiExpirationDate: "2027-05-20",
    marketingApiExpirationDate: "2027-01-21",
    status: "ACTIVE_STABLE",
    notes: "Supported active release."
  },
  "v21.0": {
    version: "v21.0",
    releaseDate: "2024-10-02",
    graphApiExpirationDate: "2027-01-21",
    marketingApiExpirationDate: "2025-09-09",
    status: "DEPRECATED",
    notes: "Marketing API sunset September 9, 2025. Graph API active through January 21, 2027."
  }
};

/**
 * Active version constants.
 * Can be overridden via environment variables for staging or canary testing.
 */
export const META_GRAPH_API_VERSION = process.env.META_GRAPH_API_VERSION || "v26.0";
export const META_MARKETING_API_VERSION = process.env.META_MARKETING_API_VERSION || "v26.0";

export const META_GRAPH_API_BASE = `https://graph.facebook.com/${META_GRAPH_API_VERSION}`;
export const META_MARKETING_API_BASE = `https://graph.facebook.com/${META_MARKETING_API_VERSION}`;

// Backwards-compatible aliases
export const META_GRAPH_VERSION = META_GRAPH_API_VERSION;
export const META_GRAPH_BASE = META_GRAPH_API_BASE;

/**
 * Returns formatted Graph API URL for a relative endpoint.
 */
export function getGraphApiUrl(endpoint: string): string {
  const cleanEndpoint = endpoint.startsWith("/") ? endpoint.substring(1) : endpoint;
  return `${META_GRAPH_API_BASE}/${cleanEndpoint}`;
}

/**
 * Returns formatted Marketing API URL for a relative endpoint.
 */
export function getMarketingApiUrl(endpoint: string): string {
  const cleanEndpoint = endpoint.startsWith("/") ? endpoint.substring(1) : endpoint;
  return `${META_MARKETING_API_BASE}/${cleanEndpoint}`;
}
