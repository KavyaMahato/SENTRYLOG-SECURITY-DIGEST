# SentryLog Security Digest

A RHEL 10 mini-project that automates daily security log review for a busy production server: persistent journaling, time-synced log correlation, pattern-based event extraction, suspicious-IP detection, and dual scheduling via systemd and cron.

## Problem Statement

An IT operations team manages a RHEL server that produces thousands of journal entries every day. Reviewing logs manually means important security events — failed logins, service failures, high-priority errors — are easy to miss, especially overnight when nobody is watching. The requirements from IT/security:

- Journal history must survive a reboot, so no data is lost when the system restarts.
- System time must be accurate, since correlating events across services depends on trustworthy timestamps.
- A script must extract failed authentication attempts, service failures, and error-or-above priority entries from the journal automatically.
- Any source IP responsible for more than 5 failed login attempts must be flagged as suspicious in the output.
- The digest must run unattended, on a daily schedule, without a human triggering it.
- Old reports must not accumulate forever — they need automatic cleanup after a retention period.

## Technical Approach

| Requirement | Tool / Mechanism | Why |
|---|---|---|
| Persistent journal | `mkdir /var/log/journal` + `systemd-tmpfiles --create` | Switches the journal from volatile (RAM-only) to persistent storage, so `journalctl -b -1` still works after a reboot |
| Time accuracy | `chronyd` + `chronyc tracking` | Log correlation across services is only meaningful if every timestamp is trustworthy; chrony keeps the clock synced to NTP sources |
| Event extraction | `journalctl` piped to `grep -E` | Regex filtering isolates failed logins, service failures, and `err`-priority entries without needing a full log-management stack |
| Suspicious-IP detection | Bash associative array (`declare -A`) | Counts failed attempts per source IP in a single pass over the extracted log, flagging any IP over the threshold as `SUSPECT` |
| Scheduling (primary) | `systemd` service + timer, `Persistent=true` | A missed 06:00 run (e.g. VM was off) automatically catches up as soon as the system is back — cron cannot do this natively |
| Scheduling (comparison) | `cron` (`crontab -e`) | Demonstrates the traditional alternative to systemd timers, useful for comparing catch-up behaviour |
| Report retention | `tmpfiles.d` rule (`e ... - - - 30d`) | Deletes reports older than 30 days automatically, so `/var/log/sentrylog/` never grows unbounded |

All steps use only standard RH134 syllabus tools: `journalctl`, `chronyc`, `systemctl`, `crontab`, `systemd-tmpfiles`. No third-party monitoring agents required.

## Repository Structure

sentrylog-security-digest/
├── sentrylog.sh # Core log-extraction and IP-flagging script
├── sentrylog.service # systemd service unit
├── sentrylog.timer # systemd timer unit (06:00 daily, Persistent=true)
├── README.md # This file
├── commands.txt # Command log, including failed attempts
├── verification.txt # Verification command output
└── screenshots/
├── 01-persistent-journal.png
├── 02-chrony-sync.png
├── 03-sample-report.png
├── 04-systemd-timer.png
└── 05-crontab.png


## How to Run

```bash
sudo chmod +x sentrylog.sh
sudo ./sentrylog.sh
```

To install the scheduled service:
```bash
sudo cp sentrylog.service sentrylog.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now sentrylog.timer
```

## Verify It

See `commands.txt` for the full development log and `verification.txt` for captured output of `journalctl --list-boots`, `chronyc tracking`, the generated security report, `systemctl list-timers`, and `crontab -l`.

## Screenshots

- `screenshots/01-persistent-journal.png` — `journalctl --list-boots` showing entries preserved across a reboot
- `screenshots/02-chrony-sync.png` — `chronyc tracking` confirming synchronised system time
- `screenshots/03-sample-report.png` — a generated `security_report_<date>.txt`, including a flagged `SUSPECT` IP
- `screenshots/04-systemd-timer.png` — `systemctl list-timers` showing `sentrylog.timer` active and scheduled
- `screenshots/05-crontab.png` — `crontab -l` showing the equivalent cron entry

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
