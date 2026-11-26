#!/usr/bin/env python3
"""Recommend the handoff model for right now, from Ollama Cloud's peak hours.

usage: pick_model.py [--json]

Ollama Cloud bills some DeepSeek models at half price off-peak. Off-peak is
outside 12:00-18:00 UTC on weekdays, and all day on weekends (ollama.com/pricing,
checked 2026-11-22). GLM has no off-peak rate, so:
  off-peak -> DeepSeek V4 Pro (cheapest, strong on repo bug-fixing)
  peak     -> GLM-5.3          (DeepSeek at full price loses its cost edge)
Inkling 2 Small is always offered as a third option (cheapest at any hour,
$0.30/$1.00 per 1M; no off-peak rate). It is on trial, so it is never the default.
Prints the recommended model first, then the alternatives, and why.
"""
import datetime
import json
import sys

DEEPSEEK = "ollama-cloud/deepseek-v4-pro"
GLM = "ollama-cloud/glm-5.3"
INKLING = "ollama-cloud/inkling-2-small"
PEAK_START, PEAK_END = 12, 18  # UTC hours, weekdays only


def main():
    now = datetime.datetime.now(datetime.timezone.utc)
    weekend = now.weekday() >= 5
    peak = not weekend and PEAK_START <= now.hour < PEAK_END
    if peak:
        rec, alt = GLM, DEEPSEEK
        ends = now.replace(hour=PEAK_END, minute=0, second=0, microsecond=0)
        why = (f"peak hours (weekday {PEAK_START}:00-{PEAK_END}:00 UTC); "
               f"off-peak resumes in {int((ends - now).total_seconds() // 60)} min")
    else:
        rec, alt = DEEPSEEK, GLM
        why = "off-peak (weekend)" if weekend else "off-peak (outside weekday 12:00-18:00 UTC)"
        why += ": DeepSeek V4 Pro is half price"
    if "--json" in sys.argv:
        print(json.dumps({"recommended": rec, "alternatives": [alt, INKLING], "peak": peak,
                          "utc": now.isoformat(timespec="minutes"), "why": why}))
    else:
        print(f"recommended: {rec}\nalternatives: {alt}, {INKLING} (on trial)\n"
              f"why: {why} (now {now:%a %H:%M} UTC)")


if __name__ == "__main__":
    main()
