# Qantas Roleplay — secure Supabase setup

This is an unofficial roleplay demo only. It is not affiliated with Qantas and is not valid for travel or airport access. Use fictional data only.

## 1. Apply the secure database functions

You have already created `staff_profiles` and `boarding_passes`, and added your own user to `staff_profiles` as `admin`.

In Supabase, open **SQL Editor → New query**. Open `supabase-secure-functions.sql`, copy its entire contents into the editor, and click **Run**. This adds/ensures the private scan token and installs three restricted functions: create pass, scan/redeem pass, and list passes. It does not recreate your tables.

If it errors, stop and use the exact SQL error to troubleshoot rather than rerunning the original table-creation query.

## 2. Configure the website

1. In Supabase, open **Project Settings → API** (or API Keys).
2. Copy the **Project URL** and the **publishable key** (or legacy anon/public key).
3. Edit `supabase-config.js` and replace both placeholders.
4. Never put a `service_role` key, secret key, database password, or other private secret in this file.

## 3. Publish on GitHub Pages

Upload/replace the files in this folder in the root of your existing GitHub repository, then commit the changes. Wait for Pages to deploy, then hard-refresh the website. If an old version persists, close and reopen the site or clear its cached site data.

## 4. Sign in and test

- Open Staff portal and sign in with the Supabase email/password for your staff account.
- Only accounts listed in `public.staff_profiles` can use staff tools.
- Create a fictional roleplay boarding pass. A random scan token is generated in the database and used in the QR code.
- Open the Scan tab and scan the QR code, or paste the token into the manual scan box.
- The first scan of an eligible pass should display the full pass details and mark it used. A second scan should show the details with **ALREADY USED**.

## Security notes

The browser uses only the public Supabase publishable/anon key. Pass-table access is revoked for browser roles; controlled RPC functions verify the signed-in user against `staff_profiles`. Do not create public signup access for staff. Remove staff access by deleting that user's row from `staff_profiles` and disabling the user in Supabase Auth. Use fictional names/emails only; this is a roleplay prototype, not a production airline system.

Lounge invitations and passenger-profile features in this prototype remain local-browser roleplay features; the secure online flow in this upgrade covers boarding-pass creation and scanning.
