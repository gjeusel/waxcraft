# Sunburst API details

The bundled CLI is the source of truth for request construction. It calls `images.generate` for midday and `images.edit` with the master PNG for each other phase, using `gpt-image-2.5-sunburst`, `quality="max"`, PNG output, and one output per request. A prompt naming the model or quality alone does not select those settings.

Use `OPENAI_API_KEY` from the local environment; never include credentials in prompts, plans, generation records, or chat. Missing credentials do not prevent planning, dry runs, contact sheets, assembly, or inspection. If an account lacks model access, report the API failure rather than substituting another model or quality.

The SDK timeout allows long generations. Automatic retries are disabled to avoid duplicating a potentially completed paid request. Authentication, quota, or request errors need resolution before retrying. Accepted images retain their request settings, usage when returned, request ID, and content hash.

Custom dimensions must have edges divisible by 16, an aspect ratio between 1:3 and 3:1, neither edge over 3840 pixels, and a total of 655,360–8,294,400 pixels. Both 3840 × 2160 and 2160 × 3840 meet those limits. Output above 2560 × 1440 is experimental. All project frames must use the same dimensions.

If the API returns smaller dimensions than requested, the CLI saves the paid output and its generation record, then fails validation. Inspect that result and resolve the request or model-access issue before generating dependent phases. Verify the explicit `size` in the dry run and generation record rather than repeating resolution instructions in the prompt. If native 4K remains unavailable, report the actual dimensions and obtain the user's choice before changing the model or using an upscale. Label upscaled output as such; increasing a raster's dimensions does not make it a native 4K generation.

Sources checked September 12, 2026; consult them if the API or SDK rejects a documented setting:

- [Sunburst model](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst)
- [Image generation and editing](https://developers.openai.com/api/docs/guides/image-generation)
