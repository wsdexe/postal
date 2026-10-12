# DNS for newly added domains

After the database migration, newly created domains receive permanent DNS names
stored in the `domains` table. Existing domains retain NULL in the new columns
and continue using the `dns` configuration exactly as before. DNS checks and
ordinary saves do not convert existing domains or regenerate names.

For new domains, the setup page provides:

- A root SPF TXT record including `spf.<domain>`.
- A TXT record at `spf.<domain>`, prefilled with all IPv4 and IPv6 addresses from
  the owning server's selected IP pool, in address creation order. If no selected
  pool has addresses (including organization-owned domains without one server),
  the page explains how to supply the addresses instead of inventing a policy.
- A word-based DKIM selector with the domain's existing individual key generator.
- One word-based return-path hostname with A, MX and SPF TXT records directly on
  that hostname, to receive delivery notifications. No CNAME or second hostname.
  The suggested A value is the first IPv4 address in the server's selected pool
  (by creation order); MX points to the return-path hostname itself, priority 10.
- An individual verification prefix, with the existing random verification token.

Words are drawn once from the bundled 7,223-word list (5–10 lowercase ASCII letters).
They are stored, not recalculated from the dictionary or configuration on each request.
See `resource/dns_words.LICENSE` for source and attribution.

Previously created individual domains retain their stored CNAME and separate target;
their MAIL FROM, DKIM and DNS requirements do not change. New rows store the same
hostname in `dns_return_path` and `dns_return_path_target` to identify direct mode.
Existing distinct values continue to identify CNAME mode. No additional database
migration or conversion of existing rows is needed for this change.

The administrator still publishes the records in DNS, and updates the SPF policy
there if the pool's addresses change. IP pools, PTR records, Message-ID
generation, message submission, tracking and root-domain MX routing are unchanged.
The return-path hostname (or existing CNAME target) must reach Postal's SMTP listener
on port 25. An explicit MX pointing to that hostname itself is recommended; an address-only hostname also supports
SMTP's implicit MX rule. No mailbox or incoming route is needed for recognized bounces.

New domains always use their individual MAIL FROM domain and DKIM identity, even
if SPF/DKIM/return-path checks report Missing or Invalid. These DNS warnings do not
block sending and never select the shared DNS fallback. Existing domain ownership
verification, credentials, suspension, limits and other sending controls are unchanged.

Incoming SMTP matches individual return paths by their complete stored hostname,
then checks that the server token belongs to the domain's server (or organization).
The existing bounce handling and X-VS-MsgID matching are reused. Legacy return-path
recognition is retained for compatibility.

## Updating an installation

Keep the existing `dns` configuration: existing domains still depend on it.
After the image build succeeds, run `postal upgrade latest` using the installation
helper. This runs the database migration before restarting services. Merely pulling
an image and restarting does not apply the required new database columns.

The migration adds nullable columns and an index; it does not rewrite existing
domain rows or rotate DKIM keys. Do not roll back the columns after creating new
domains: doing so discards their persisted DNS names.

CI checks new and legacy DNS instructions, unchanged legacy fallbacks, sending
with unverified DNS, return-path ownership and SMTP bounce processing, and a
migration round trip in the isolated test database before publishing an image.
