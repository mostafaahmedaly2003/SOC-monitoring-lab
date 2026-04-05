# Step 0 — External Accounts Setup

Before touching any VM, create the two API accounts needed for the Shuffle SOAR workflow. Both are free.

---

## VirusTotal (IP Reputation Lookups)

**Why needed:** Shuffle queries VirusTotal to check if a suspicious IP is known-malicious.

1. Go to https://www.virustotal.com/gui/join-us
2. Create a free account (email + password)
3. Verify your email
4. Log in → click your username (top right) → **API Key**
5. Copy the 64-character key

**Test from Kali:**
```bash
curl -s --request GET \
  --url "https://www.virustotal.com/api/v3/ip_addresses/8.8.8.8" \
  --header "x-apikey: YOUR_VT_API_KEY" | python3 -m json.tool | head -10
```

Expected: JSON with `"id": "8.8.8.8"`. If you see `WrongCredentialsError` — re-copy the key.

**Free tier limits:** 4 requests/minute, 500/day. Sufficient for this lab.

---

## SendGrid (Email Notifications)

**Why needed:** Shuffle sends automated alert emails via SendGrid.

1. Go to https://signup.sendgrid.com — create free account
2. Verify your email via the confirmation link
3. Complete brief onboarding (select: Transactional, Developer)
4. Dashboard → Settings → **API Keys** → Create API Key
   - Name: `soc-lab-key`
   - Permission: Restricted → Mail Send → Full Access
   - Click Create — **copy the key immediately** (shown once only)
5. Settings → **Sender Authentication** → Single Sender Verification
   - Add your email address → Save → click link in your inbox

**Test from Kali:**
```bash
curl -s --request POST \
  --url https://api.sendgrid.com/v3/mail/send \
  --header "Authorization: Bearer YOUR_SENDGRID_KEY" \
  --header "Content-Type: application/json" \
  --data '{
    "personalizations": [{"to": [{"email": "YOUR_EMAIL"}]}],
    "from": {"email": "YOUR_VERIFIED_SENDER"},
    "subject": "SOC Lab Test",
    "content": [{"type": "text/plain", "value": "SendGrid works."}]
  }'
```

Expected: HTTP 202 (empty body). Check inbox — email arrives within 1 minute.

---

## Save Your Keys

Store both keys safely before continuing:

```
VT_API_KEY=<your 64-char VirusTotal key>
SENDGRID_API_KEY=SG.<your SendGrid key>
SENDGRID_FROM_EMAIL=<your verified sender email>
ALERT_TO_EMAIL=<email to receive alerts>
```

You will paste these into Shuffle in Step 6.
