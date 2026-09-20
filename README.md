# SentryLog Security Digest 

## Problem Statement
An IT operations team manages a RHEL server that produces thousands of
journal entries every day. Reviewing logs manually means security-relevant
events — failed logins, service failures, high-priority errors — are easy
to miss. This project automates that review into a scheduled, unattended
security digest.

## Approach
1. Configured a persistent system journal so log history survives a reboot
2. Enabled and verified `chrony` for accurate time synchronisation, which
   is required to correlate events across services reliably
3. Wrote `sentrylog.sh`, which uses `journalctl` + `grep -E` to extract:
   - Failed authentication attempts
   - Service failures
   - Entries at priority `err` or above
4. Added logic to count failed-login attempts per source IP and flag any
   IP with more than 5 failures as **SUSPECT**
5. Scheduled the script two ways, for comparison:
   - A `systemd` service + timer (`sentrylog.timer`, `06:00` daily,
     `Persistent=true` so a missed run catches up automatically)
   - A `cron` entry (`0 6 * * * /usr/local/bin/sentrylog.sh`)
6. Added a `tmpfiles.d` rule to automatically delete generated reports
   older than 30 days

## Systemd Timer vs Cron
The systemd timer uses `Persistent=true`, so a run missed because the
machine was off at 06:00 executes as soon as the system comes back up.
Cron has no built-in catch-up — a missed run is simply skipped.

## Tmpfiles Configuration Note
The retention rule requires all five fields in the `tmpfiles.d` line:

e /var/log/sentrylog/*.txt - - - 30d

The three `-` placeholders mean "leave mode/owner/group unchanged" —
only the trailing `30d` (age) is being enforced here. Omitting the
placeholders causes systemd to misread `30d` as the mode field.

## Files
- `sentrylog.sh` — the report generation and IP-flagging script
- `sentrylog.service` / `sentrylog.timer` — systemd unit pair
- `commands.txt` — full recorded command log (`script -a`)
- `screenshots/` — verification evidence, including a sample
  `security_report_<date>.txt` with a flagged SUSPECT IP

## Result
Security reports are generated automatically every day. Failed login
attempts are counted per source IP with suspicious activity flagged,
the task runs reliably under both a systemd timer and cron, and old
reports are cleaned up automatically after 30 days.
