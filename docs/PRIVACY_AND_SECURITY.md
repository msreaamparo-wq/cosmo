# Privacy and security

**Local by default.** Imported pictures are copied into COSMOS' private storage (Android app storage / browser storage). Originals in the device gallery are never modified or deleted. Nothing leaves the device unless a parent enables cloud features.

**Cloud (opt-in, parent only).** Requires a Supabase parent account and turning on "Cloud sync" (with a disclosure dialog). Synced: planet details, planet↔photo links, favorite marks, photo metadata (name, type, date, size), achievements. **Photo files are uploaded only when the parent taps "Back up photos now"** (after a confirmation), to the private bucket `cosmos-media` at `{user_id}/{media_id}/{filename}`. A photo is marked backed-up only after its upload succeeds.

**Ownership.** Row Level Security on every table (`auth.uid() = parent_id`), composite foreign keys that prevent cross-parent links, Storage policies that require the first path folder to equal `auth.uid()`, no anonymous access, no `USING (true)` policies, no SECURITY DEFINER functions. Only the URL and publishable key are in the app.

**Deletion.** Removing a memory from COSMOS tombstones its record; the next sync deletes its cloud backup copy and informs other devices.

**No** ads, analytics, tracking, location, social features, messaging or public sharing. (Sharing a photo uses the system share sheet, started by the user.)

## Limitations (please read)
- The **parent gate is a child barrier, not authentication.**
- Session persistence uses `supabase_flutter`'s default storage (not an encrypted keystore).
- Photos in the cloud are protected by access rules, not end-to-end encrypted: Supabase can technically access stored files.
- Conflict resolution is last-writer-wins on device clocks; a badly wrong clock can win unfairly.
- **No legal review** has been done for COPPA, GDPR-K or app-store children's policies. Do one before any public release.
- Browser storage can be cleared by the user or the browser, which deletes web-imported photos (back them up first).
