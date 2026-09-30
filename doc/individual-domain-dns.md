# DNS for newly added domains

After the database migration, newly created domains receive permanent DNS names
stored in the `domains` table. Existing domains retain NULL in the new columns
and continue using the `dns` configuration exactly as before. DNS checks and
ordinary saves do not convert existing domains or regenerate names.

For new domains, the setup page provides:

- A root SPF TXT record including `spf.<domain>`.
- A TXT record at `spf.<domain>` where the administrator lists sending IPs.
- A word-based DKIM selector with the domain's existing individual key generator.
- A word-based return-path CNAME and a different word-based target in the same domain.
- A, MX and SPF TXT instructions for the CNAME target, to receive delivery notifications.
- An individual verification prefix, with the existing random verification token.

Words are drawn once from the bundled 7,223-word list (5–10 lowercase ASCII letters).
They are stored, not recalculated from the dictionary or configuration on each request.
See `resource/dns_words.LICENSE` for source and attribution.

The administrator supplies IP addresses in DNS. IP pools, PTR records, Message-ID
generation, message submission, tracking and root-domain MX routing are unchanged.
The CNAME target must reach Postal's SMTP listener on port 25. An explicit MX
pointing to the target itself is recommended; an address-only target also supports
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
