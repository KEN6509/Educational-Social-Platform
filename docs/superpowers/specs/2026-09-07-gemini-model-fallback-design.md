# Gemini Model Fallback Design

**Date:** September 7, 2026  
**Status:** Approved

**Scope:** CyanZone privileged API moderation provider only

## Goal

Use `gemini-3.5-flash-lite` as the economical, low-latency primary model while
allowing one controlled `gemini-3.8-flash` fallback when the primary model is
rate-limited or temporarily unavailable. Preserve CyanZone's 20-second
moderation target and existing same-record retry behavior.

## Configuration

The API reads these server-only environment variables:

```text
GEMINI_API_KEY=<secret>
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_FALLBACK_MODEL=gemini-3.8-flash
GEMINI_TIMEOUT_MS=8500
```

`GEMINI_MODEL` remains the primary-model variable for backward compatibility.
`GEMINI_FALLBACK_MODEL` is new. Neither model name nor the API key is exposed to
Flutter or the Administration Portal. The fallback model must differ from the
primary model.

## Request Policy

The provider owns the complete within-request retry policy. The moderation
service calls the provider once, preventing the current service retry from
multiplying a two-model fallback into four Gemini requests.

Each moderation request makes at most two provider calls:

1. Call the configured primary model.
2. If the primary returns HTTP `429` or `503`, call the configured fallback
   model once.
3. If the primary fails with another retryable transport/provider failure,
   retry the primary model once instead of switching models.
4. Do not make a second call for an explicit safety block, invalid request,
   malformed structured output, or other permanent provider failure.

Each provider call retains the existing 8.5-second timeout. Two calls therefore
have a maximum provider budget of 17 seconds, leaving approximately three
seconds for API, database, and client overhead within the 20-second target.

## Results and Failure Handling

Successful moderation persists:

- the model that produced the accepted result;
- the total provider attempt count;
- the existing score, evidence, prompt version, timestamps, and decision
  source.

An explicit Gemini safety block remains fail-closed and becomes a rejected
moderation result. It never triggers model fallback.

If both permitted calls fail, the API marks the moderation case as failed,
keeps the post or comment unpublished, and returns the existing retryable
service response. Flutter retains the same post/comment ID in its persistent
moderation retry store, so the member can retry without creating duplicate
content.

## Components

- `env.ts` validates the primary model, fallback model, and timeout.
- `GeminiModerationGateway` builds the same structured multimodal request for
  either model and owns the two-call policy.
- `ModerationProviderError` carries safe status/attempt metadata needed to
  select the second call and persist the attempt count.
- `ModerationService` performs one provider invocation and continues to own
  repository preparation, score thresholds, safety-result persistence, failed
  case persistence, and client response mapping.

The public mobile and Administration Portal APIs do not change.

## Testing

Automated tests must prove:

- the default primary and fallback model configuration;
- `429` and `503` switch from 3.5 Flash-Lite to 3.8 Flash;
- timeout and other retryable non-fallback errors retry the primary once;
- safety blocks and permanent failures make only one call;
- two failed attempts do not trigger a third call;
- the successful model and actual attempt count are persisted;
- existing moderation thresholds, immutable snapshots, Admin review, and
  same-record mobile retry tests remain green.

A manual smoke test will use the configured API key to confirm one safe text
request through the primary model. Fallback behavior will be proven
deterministically with automated fake-provider tests instead of intentionally
exhausting live quota.

## Deployment Boundary

This change prepares local and Vercel configuration but does not deploy the API
or modify live Supabase data. After implementation and local verification, the
same three Gemini variables must be added to the Vercel API project. The
Supabase moderation migration remains a separate guided step.
