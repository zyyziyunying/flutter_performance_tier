#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

SUPPORTED_SUFFIXES = {".json", ".jsonl", ".ndjson", ".log", ".txt"}
ACTIVE_RUNTIME_STATUSES = {"pending", "active", "cooldown", "recovery-pending"}
SESSION_HEADERS = [
    "source_file",
    "source_ref",
    "source_type",
    "report_status",
    "generated_at",
    "session_id",
    "initializing",
    "tier",
    "confidence",
    "decided_at",
    "runtime_status",
    "runtime_trigger_reason",
    "status_duration_ms",
    "downgrade_trigger_count",
    "recovery_trigger_count",
    "platform",
    "device_model",
    "total_ram_bytes",
    "total_ram_gb",
    "is_low_ram_device",
    "media_performance_class",
    "sdk_int",
    "thermal_state",
    "thermal_state_level",
    "is_low_power_mode_enabled",
    "memory_pressure_state",
    "memory_pressure_level",
    "frame_drop_state",
    "frame_drop_level",
    "frame_drop_rate",
    "frame_dropped_count",
    "frame_sampled_count",
    "reason_count",
    "reasons_json",
    "applied_policies_json",
    "recent_structured_log_count",
    "upload_client",
    "upload_running",
    "upload_result",
    "upload_error",
    "top_level_error",
    "is_fallback",
]
EVENT_HEADERS = [
    "source_file",
    "source_ref",
    "origin",
    "session_id",
    "event",
    "timestamp",
    "trigger",
    "transition_type",
    "tier_changed",
    "runtime_status_changed",
    "from_tier",
    "to_tier",
    "from_runtime_status",
    "to_runtime_status",
    "decision_tier",
    "decision_confidence",
    "decision_runtime_status",
    "payload_json",
]
DEVICE_HEADERS = [
    "platform",
    "device_model",
    "sample_count",
    "tier_distribution",
    "runtime_status_distribution",
    "unique_tier_count",
    "active_runtime_rate",
    "avg_downgrade_trigger_count",
    "avg_recovery_trigger_count",
    "avg_frame_drop_rate",
    "avg_total_ram_gb",
    "fallback_count",
    "missing_total_ram_count",
]
FLAGGED_HEADERS = [
    "source_ref",
    "session_id",
    "platform",
    "device_model",
    "tier",
    "runtime_status",
    "downgrade_trigger_count",
    "frame_drop_rate",
    "flags",
    "reason_excerpt",
]
ISSUE_HEADERS = ["source_ref", "issue", "detail"]


@dataclass(slots=True)
class ParseIssue:
    source_ref: str
    issue: str
    detail: str


def json_compact(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def looks_like_report(value: Any) -> bool:
    return isinstance(value, dict) and (
        "decision" in value or "recentStructuredLogs" in value or "uploadProbe" in value
    )


def looks_like_decision(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and "tier" in value
        and "deviceSignals" in value
        and "runtimeObservation" in value
    )


def looks_like_log_record(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and isinstance(value.get("event"), str)
        and isinstance(value.get("timestamp"), str)
        and isinstance(value.get("payload"), dict)
    )


def normalize_bool(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return ""


def safe_int(value: Any) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return None
        try:
            return int(float(stripped))
        except ValueError:
            return None
    return None


def safe_float(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return None
        try:
            return float(stripped)
        except ValueError:
            return None
    return None


def safe_str(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    return str(value)


def average(values: Iterable[float]) -> float | None:
    items = [value for value in values if value is not None]
    if not items:
        return None
    return sum(items) / len(items)


def format_percent(numerator: int, denominator: int) -> str:
    if denominator == 0:
        return "0.0%"
    return f"{(numerator / denominator) * 100:.1f}%"


def format_float(value: float | None, digits: int = 3) -> str:
    if value is None:
        return ""
    return f"{value:.{digits}f}"


def counter_to_text(counter: Counter[str]) -> str:
    if not counter:
        return ""
    parts = [f"{key}:{counter[key]}" for key in sorted(counter)]
    return ", ".join(parts)


def trim_reason_excerpt(reasons_json: str, max_length: int = 180) -> str:
    if not reasons_json:
        return ""
    try:
        reasons = json.loads(reasons_json)
        if isinstance(reasons, list):
            text = " | ".join(safe_str(item) for item in reasons[:3])
        else:
            text = safe_str(reasons)
    except json.JSONDecodeError:
        text = reasons_json
    if len(text) <= max_length:
        return text
    return f"{text[: max_length - 3]}..."


class DiagnosticsAnalyzer:
    def __init__(self, prefix: str, top_n: int) -> None:
        self.prefix = prefix
        self.top_n = top_n
        self.session_rows: list[dict[str, Any]] = []
        self.event_rows: list[dict[str, Any]] = []
        self.device_rows: list[dict[str, Any]] = []
        self.flagged_rows: list[dict[str, Any]] = []
        self.issues: list[ParseIssue] = []
        self.files_scanned = 0
        self._report_session_keys: set[tuple[str, str]] = set()

    def ingest_files(self, paths: Iterable[Path]) -> None:
        for path in sorted(paths):
            self.files_scanned += 1
            if path.suffix.lower() == ".json":
                self._ingest_json_file(path)
            else:
                self._ingest_line_file(path)
        self._derive_sessions_from_events()
        self._build_device_rows()
        self._build_flagged_rows()

    def write_outputs(self, output_dir: Path) -> None:
        output_dir.mkdir(parents=True, exist_ok=True)
        self._write_csv(output_dir / "session_summary.csv", SESSION_HEADERS, self.session_rows)
        self._write_csv(output_dir / "event_timeline.csv", EVENT_HEADERS, self.event_rows)
        self._write_csv(output_dir / "device_model_summary.csv", DEVICE_HEADERS, self.device_rows)
        self._write_csv(output_dir / "flagged_sessions.csv", FLAGGED_HEADERS, self.flagged_rows)
        self._write_csv(
            output_dir / "parse_issues.csv",
            ISSUE_HEADERS,
            [issue.__dict__ for issue in self.issues],
        )
        (output_dir / "summary.md").write_text(self._build_summary_markdown(), encoding="utf-8")

    def _ingest_json_file(self, path: Path) -> None:
        source_ref = str(path)
        try:
            text = path.read_text(encoding="utf-8-sig")
        except UnicodeDecodeError:
            text = path.read_text(encoding="utf-8", errors="replace")
        if not text.strip():
            self.issues.append(ParseIssue(source_ref, "empty_file", "File contains no JSON."))
            return
        try:
            data = json.loads(text)
        except json.JSONDecodeError as error:
            self.issues.append(ParseIssue(source_ref, "json_decode_error", str(error)))
            return
        self._ingest_value(data, path, source_ref)

    def _ingest_line_file(self, path: Path) -> None:
        try:
            lines = path.read_text(encoding="utf-8-sig").splitlines()
        except UnicodeDecodeError:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for index, raw_line in enumerate(lines, start=1):
            line = raw_line.strip()
            if not line:
                continue
            json_text = self._extract_json_text_from_line(line)
            if json_text is None:
                continue
            source_ref = f"{path}:{index}"
            try:
                data = json.loads(json_text)
            except json.JSONDecodeError as error:
                self.issues.append(ParseIssue(source_ref, "json_decode_error", str(error)))
                continue
            self._ingest_value(data, path, source_ref)

    def _extract_json_text_from_line(self, line: str) -> str | None:
        if line.startswith(f"{self.prefix} "):
            return line[len(self.prefix) + 1 :].strip()
        if line.startswith("{") or line.startswith("["):
            return line
        return None

    def _ingest_value(self, value: Any, source_file: Path, source_ref: str) -> None:
        if isinstance(value, list):
            for index, item in enumerate(value, start=1):
                self._ingest_value(item, source_file, f"{source_ref}#{index}")
            return
        if looks_like_report(value):
            self._add_report_row(source_file, source_ref, value, "ai-report")
            return
        if looks_like_decision(value):
            self._add_decision_row(source_file, source_ref, value, "decision-only")
            return
        if looks_like_log_record(value):
            event_row = self._build_event_row(source_file, source_ref, value, "log-record")
            self.event_rows.append(event_row)
            return
        self.issues.append(
            ParseIssue(source_ref, "unsupported_shape", f"Unsupported JSON shape: {type(value).__name__}")
        )

    def _add_report_row(
        self,
        source_file: Path,
        source_ref: str,
        report: dict[str, Any],
        source_type: str,
    ) -> None:
        logs = report.get("recentStructuredLogs")
        recent_structured_log_count = len(logs) if isinstance(logs, list) else 0
        embedded_events = self._parse_embedded_logs(source_file, source_ref, logs)
        session_id = self._pick_session_id(embedded_events)
        row = self._build_session_row(
            source_file=source_file,
            source_ref=source_ref,
            source_type=source_type,
            report_status=safe_str(report.get("status")),
            generated_at=safe_str(report.get("generatedAt")),
            initializing=normalize_bool(report.get("initializing")),
            decision=report.get("decision"),
            top_level_error=safe_str(report.get("error")),
            recent_structured_log_count=recent_structured_log_count,
            upload_probe=report.get("uploadProbe"),
            session_id=session_id,
        )
        self.session_rows.append(row)
        if session_id:
            self._report_session_keys.add((row["source_file"], session_id))

    def _add_decision_row(
        self,
        source_file: Path,
        source_ref: str,
        decision: dict[str, Any],
        source_type: str,
    ) -> None:
        row = self._build_session_row(
            source_file=source_file,
            source_ref=source_ref,
            source_type=source_type,
            report_status="ok",
            generated_at=safe_str(decision.get("decidedAt")),
            initializing="false",
            decision=decision,
            top_level_error="",
            recent_structured_log_count=0,
            upload_probe=None,
            session_id="",
        )
        self.session_rows.append(row)

    def _parse_embedded_logs(
        self,
        source_file: Path,
        source_ref: str,
        log_lines: Any,
    ) -> list[dict[str, Any]]:
        events: list[dict[str, Any]] = []
        if not isinstance(log_lines, list):
            return events
        for index, item in enumerate(log_lines, start=1):
            item_ref = f"{source_ref}::recentStructuredLogs[{index}]"
            if isinstance(item, str):
                json_text = self._extract_json_text_from_line(item.strip())
                if json_text is None:
                    self.issues.append(
                        ParseIssue(item_ref, "unsupported_log_line", "Embedded log line does not contain JSON.")
                    )
                    continue
                try:
                    payload = json.loads(json_text)
                except json.JSONDecodeError as error:
                    self.issues.append(ParseIssue(item_ref, "json_decode_error", str(error)))
                    continue
            elif isinstance(item, dict):
                payload = item
            else:
                self.issues.append(
                    ParseIssue(item_ref, "unsupported_log_item", f"Unsupported item: {type(item).__name__}")
                )
                continue
            if not looks_like_log_record(payload):
                self.issues.append(
                    ParseIssue(item_ref, "unsupported_log_record", "Embedded item is not a log record.")
                )
                continue
            event_row = self._build_event_row(source_file, item_ref, payload, "embedded-log")
            self.event_rows.append(event_row)
            events.append(event_row)
        return events

    def _build_session_row(
        self,
        *,
        source_file: Path,
        source_ref: str,
        source_type: str,
        report_status: str,
        generated_at: str,
        initializing: str,
        decision: Any,
        top_level_error: str,
        recent_structured_log_count: int,
        upload_probe: Any,
        session_id: str,
    ) -> dict[str, Any]:
        decision_map = decision if isinstance(decision, dict) else {}
        device_signals = decision_map.get("deviceSignals")
        runtime = decision_map.get("runtimeObservation")
        reasons = decision_map.get("reasons")
        applied_policies = decision_map.get("appliedPolicies")
        upload_map = upload_probe if isinstance(upload_probe, dict) else {}

        reason_list = reasons if isinstance(reasons, list) else []
        fallback = any("Failed to collect platform signals" in safe_str(item) for item in reason_list)
        total_ram_bytes = safe_int(_maybe_dict_value(device_signals, "totalRamBytes"))
        total_ram_gb = total_ram_bytes / (1024 ** 3) if total_ram_bytes is not None else None

        return {
            "source_file": str(source_file),
            "source_ref": source_ref,
            "source_type": source_type,
            "report_status": report_status,
            "generated_at": generated_at,
            "session_id": session_id,
            "initializing": initializing,
            "tier": safe_str(decision_map.get("tier")),
            "confidence": safe_str(decision_map.get("confidence")),
            "decided_at": safe_str(decision_map.get("decidedAt")),
            "runtime_status": safe_str(_maybe_dict_value(runtime, "status")),
            "runtime_trigger_reason": safe_str(_maybe_dict_value(runtime, "triggerReason")),
            "status_duration_ms": safe_int(_maybe_dict_value(runtime, "statusDurationMs")),
            "downgrade_trigger_count": safe_int(_maybe_dict_value(runtime, "downgradeTriggerCount")),
            "recovery_trigger_count": safe_int(_maybe_dict_value(runtime, "recoveryTriggerCount")),
            "platform": safe_str(_maybe_dict_value(device_signals, "platform")),
            "device_model": safe_str(_maybe_dict_value(device_signals, "deviceModel")),
            "total_ram_bytes": total_ram_bytes,
            "total_ram_gb": format_float(total_ram_gb, 2),
            "is_low_ram_device": normalize_bool(_maybe_dict_value(device_signals, "isLowRamDevice")),
            "media_performance_class": safe_int(_maybe_dict_value(device_signals, "mediaPerformanceClass")),
            "sdk_int": safe_int(_maybe_dict_value(device_signals, "sdkInt")),
            "thermal_state": safe_str(_maybe_dict_value(device_signals, "thermalState")),
            "thermal_state_level": safe_int(_maybe_dict_value(device_signals, "thermalStateLevel")),
            "is_low_power_mode_enabled": normalize_bool(
                _maybe_dict_value(device_signals, "isLowPowerModeEnabled")
            ),
            "memory_pressure_state": safe_str(_maybe_dict_value(device_signals, "memoryPressureState")),
            "memory_pressure_level": safe_int(_maybe_dict_value(device_signals, "memoryPressureLevel")),
            "frame_drop_state": safe_str(_maybe_dict_value(device_signals, "frameDropState")),
            "frame_drop_level": safe_int(_maybe_dict_value(device_signals, "frameDropLevel")),
            "frame_drop_rate": safe_float(_maybe_dict_value(device_signals, "frameDropRate")),
            "frame_dropped_count": safe_int(_maybe_dict_value(device_signals, "frameDroppedCount")),
            "frame_sampled_count": safe_int(_maybe_dict_value(device_signals, "frameSampledCount")),
            "reason_count": len(reason_list),
            "reasons_json": json_compact(reason_list),
            "applied_policies_json": json_compact(applied_policies if isinstance(applied_policies, dict) else {}),
            "recent_structured_log_count": recent_structured_log_count,
            "upload_client": safe_str(upload_map.get("client")),
            "upload_running": normalize_bool(upload_map.get("running")),
            "upload_result": safe_str(upload_map.get("result")),
            "upload_error": safe_str(upload_map.get("error")),
            "top_level_error": top_level_error,
            "is_fallback": "true" if fallback else "false",
        }

    def _build_event_row(
        self,
        source_file: Path,
        source_ref: str,
        record: dict[str, Any],
        origin: str,
    ) -> dict[str, Any]:
        payload = record.get("payload")
        payload_map = payload if isinstance(payload, dict) else {}
        transition = payload_map.get("transition")
        transition_map = transition if isinstance(transition, dict) else {}
        decision = payload_map.get("decision")
        decision_map = decision if isinstance(decision, dict) else {}
        runtime = decision_map.get("runtimeObservation")
        runtime_map = runtime if isinstance(runtime, dict) else {}

        return {
            "source_file": str(source_file),
            "source_ref": source_ref,
            "origin": origin,
            "session_id": safe_str(record.get("sessionId")),
            "event": safe_str(record.get("event")),
            "timestamp": safe_str(record.get("timestamp")),
            "trigger": safe_str(payload_map.get("trigger")),
            "transition_type": safe_str(transition_map.get("type")),
            "tier_changed": normalize_bool(transition_map.get("tierChanged")),
            "runtime_status_changed": normalize_bool(transition_map.get("runtimeStatusChanged")),
            "from_tier": safe_str(transition_map.get("fromTier")),
            "to_tier": safe_str(transition_map.get("toTier")),
            "from_runtime_status": safe_str(transition_map.get("fromRuntimeStatus")),
            "to_runtime_status": safe_str(transition_map.get("toRuntimeStatus")),
            "decision_tier": safe_str(decision_map.get("tier")),
            "decision_confidence": safe_str(decision_map.get("confidence")),
            "decision_runtime_status": safe_str(runtime_map.get("status")),
            "payload_json": json_compact(payload_map),
            "_decision": decision_map,
        }

    def _pick_session_id(self, event_rows: Iterable[dict[str, Any]]) -> str:
        counter = Counter(
            row["session_id"]
            for row in event_rows
            if isinstance(row.get("session_id"), str) and row["session_id"]
        )
        if not counter:
            return ""
        return counter.most_common(1)[0][0]

    def _derive_sessions_from_events(self) -> None:
        groups: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
        for event_row in self.event_rows:
            session_id = safe_str(event_row.get("session_id"))
            groups[(safe_str(event_row.get("source_file")), session_id)].append(event_row)

        derived_rows: list[dict[str, Any]] = []
        for (source_file, session_id), rows in groups.items():
            if session_id and (source_file, session_id) in self._report_session_keys:
                continue
            decision_rows = [row for row in rows if isinstance(row.get("_decision"), dict) and row["_decision"]]
            if not decision_rows:
                continue
            latest = sorted(
                decision_rows,
                key=lambda row: (safe_str(row.get("timestamp")), safe_str(row.get("source_ref"))),
            )[-1]
            derived_rows.append(
                self._build_session_row(
                    source_file=Path(source_file),
                    source_ref=safe_str(latest.get("source_ref")),
                    source_type="log-session",
                    report_status="ok",
                    generated_at=safe_str(latest.get("timestamp")),
                    initializing="false",
                    decision=latest.get("_decision"),
                    top_level_error="",
                    recent_structured_log_count=0,
                    upload_probe=None,
                    session_id=session_id,
                )
            )
        self.session_rows.extend(derived_rows)

    def _build_device_rows(self) -> None:
        groups: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
        for row in self.session_rows:
            key = (
                row.get("platform") or "unknown",
                row.get("device_model") or "unknown",
            )
            groups[key].append(row)

        device_rows: list[dict[str, Any]] = []
        for (platform, device_model), rows in groups.items():
            tier_counter = Counter(safe_str(row.get("tier")) or "missing" for row in rows)
            runtime_counter = Counter(safe_str(row.get("runtime_status")) or "missing" for row in rows)
            active_count = sum(
                1 for row in rows if safe_str(row.get("runtime_status")) in ACTIVE_RUNTIME_STATUSES
            )
            fallback_count = sum(1 for row in rows if row.get("is_fallback") == "true")
            missing_total_ram_count = sum(1 for row in rows if row.get("total_ram_bytes") is None)
            device_rows.append(
                {
                    "platform": platform,
                    "device_model": device_model,
                    "sample_count": len(rows),
                    "tier_distribution": counter_to_text(tier_counter),
                    "runtime_status_distribution": counter_to_text(runtime_counter),
                    "unique_tier_count": len({key for key in tier_counter if key and key != "missing"}),
                    "active_runtime_rate": format_percent(active_count, len(rows)),
                    "avg_downgrade_trigger_count": format_float(
                        average(
                            safe_float(row.get("downgrade_trigger_count"))
                            for row in rows
                            if row.get("downgrade_trigger_count") is not None
                        ),
                        2,
                    ),
                    "avg_recovery_trigger_count": format_float(
                        average(
                            safe_float(row.get("recovery_trigger_count"))
                            for row in rows
                            if row.get("recovery_trigger_count") is not None
                        ),
                        2,
                    ),
                    "avg_frame_drop_rate": format_float(
                        average(
                            safe_float(row.get("frame_drop_rate"))
                            for row in rows
                            if row.get("frame_drop_rate") is not None
                        ),
                        3,
                    ),
                    "avg_total_ram_gb": format_float(
                        average(
                            safe_float(row.get("total_ram_gb"))
                            for row in rows
                            if row.get("total_ram_gb")
                        ),
                        2,
                    ),
                    "fallback_count": fallback_count,
                    "missing_total_ram_count": missing_total_ram_count,
                }
            )
        self.device_rows = sorted(
            device_rows,
            key=lambda row: (
                -safe_int(row.get("sample_count")) if row.get("sample_count") is not None else 0,
                row.get("platform") or "",
                row.get("device_model") or "",
            ),
        )

    def _build_flagged_rows(self) -> None:
        volatile_device_keys = {
            (row["platform"], row["device_model"])
            for row in self.device_rows
            if safe_int(row.get("sample_count")) is not None
            and safe_int(row.get("sample_count")) >= 2
            and safe_int(row.get("unique_tier_count")) is not None
            and safe_int(row.get("unique_tier_count")) >= 2
        }

        flagged_rows: list[dict[str, Any]] = []
        for row in self.session_rows:
            flags: list[str] = []
            if row.get("is_fallback") == "true":
                flags.append("fallback_decision")
            if not row.get("device_model"):
                flags.append("missing_device_model")
            if row.get("total_ram_bytes") is None:
                flags.append("missing_total_ram")
            if not row.get("runtime_status"):
                flags.append("missing_runtime_status")
            downgrade_count = safe_int(row.get("downgrade_trigger_count"))
            if downgrade_count is not None and downgrade_count >= 3:
                flags.append("frequent_runtime_downgrade")
            frame_drop_rate = safe_float(row.get("frame_drop_rate"))
            if frame_drop_rate is not None and frame_drop_rate >= 0.20:
                flags.append("high_frame_drop_rate")
            if safe_str(row.get("runtime_status")) in {"active", "cooldown"}:
                flags.append("runtime_pressure_observed")
            device_key = (
                row.get("platform") or "unknown",
                row.get("device_model") or "unknown",
            )
            if device_key in volatile_device_keys:
                flags.append("tier_variation_same_model")
            if not flags:
                continue
            flagged_rows.append(
                {
                    "source_ref": row.get("source_ref"),
                    "session_id": row.get("session_id"),
                    "platform": row.get("platform"),
                    "device_model": row.get("device_model"),
                    "tier": row.get("tier"),
                    "runtime_status": row.get("runtime_status"),
                    "downgrade_trigger_count": row.get("downgrade_trigger_count"),
                    "frame_drop_rate": row.get("frame_drop_rate"),
                    "flags": ", ".join(flags),
                    "reason_excerpt": trim_reason_excerpt(safe_str(row.get("reasons_json"))),
                }
            )
        self.flagged_rows = flagged_rows

    def _write_csv(
        self,
        path: Path,
        headers: list[str],
        rows: list[dict[str, Any]],
    ) -> None:
        with path.open("w", encoding="utf-8-sig", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=headers, extrasaction="ignore")
            writer.writeheader()
            for row in rows:
                writer.writerow(row)

    def _build_summary_markdown(self) -> str:
        session_count = len(self.session_rows)
        event_count = len(self.event_rows)
        issue_count = len(self.issues)
        fallback_count = sum(1 for row in self.session_rows if row.get("is_fallback") == "true")

        device_model_complete = sum(1 for row in self.session_rows if row.get("device_model"))
        ram_complete = sum(1 for row in self.session_rows if row.get("total_ram_bytes") is not None)
        runtime_complete = sum(1 for row in self.session_rows if row.get("runtime_status"))

        tier_counter = Counter(safe_str(row.get("tier")) or "missing" for row in self.session_rows)
        runtime_counter = Counter(
            safe_str(row.get("runtime_status")) or "missing" for row in self.session_rows
        )
        trigger_counter = Counter(
            safe_str(row.get("runtime_trigger_reason"))
            for row in self.session_rows
            if row.get("runtime_trigger_reason")
        )

        top_devices = self.device_rows[: self.top_n]
        top_flags = self.flagged_rows[: self.top_n]

        lines = [
            "# Diagnostics Summary",
            "",
            f"- Generated at: {datetime.now(timezone.utc).isoformat()}",
            f"- Files scanned: {self.files_scanned}",
            f"- Session rows: {session_count}",
            f"- Structured log events: {event_count}",
            f"- Parse issues: {issue_count}",
            "",
            "## Data quality",
            "",
            f"- `deviceModel` completeness: {device_model_complete}/{session_count} ({format_percent(device_model_complete, session_count)})",
            f"- `totalRamBytes` completeness: {ram_complete}/{session_count} ({format_percent(ram_complete, session_count)})",
            f"- `runtimeObservation.status` completeness: {runtime_complete}/{session_count} ({format_percent(runtime_complete, session_count)})",
            f"- Fallback decisions: {fallback_count}",
            "",
            "## Tier distribution",
            "",
        ]

        if tier_counter:
            for key, value in tier_counter.most_common():
                lines.append(f"- `{key}`: {value}")
        else:
            lines.append("- No tier data found.")

        lines.extend(["", "## Runtime status distribution", ""])
        if runtime_counter:
            for key, value in runtime_counter.most_common():
                lines.append(f"- `{key}`: {value}")
        else:
            lines.append("- No runtime status data found.")

        lines.extend(["", "## Top runtime trigger reasons", ""])
        if trigger_counter:
            for key, value in trigger_counter.most_common(self.top_n):
                lines.append(f"- `{key}`: {value}")
        else:
            lines.append("- No runtime trigger reasons found.")

        lines.extend(["", "## Top device models", ""])
        if top_devices:
            for row in top_devices:
                lines.append(
                    "- "
                    f"`{row['platform']}` / `{row['device_model']}`: "
                    f"samples={row['sample_count']}, "
                    f"tiers={row['tier_distribution']}, "
                    f"runtime={row['runtime_status_distribution']}, "
                    f"activeRate={row['active_runtime_rate']}"
                )
        else:
            lines.append("- No device aggregates available.")

        lines.extend(["", "## Flagged sessions", ""])
        if top_flags:
            for row in top_flags:
                lines.append(
                    "- "
                    f"`{row['source_ref']}`: "
                    f"flags={row['flags']}, "
                    f"tier={row['tier']}, "
                    f"runtime={row['runtime_status']}, "
                    f"device={row['platform']}/{row['device_model']}"
                )
        else:
            lines.append("- No flagged sessions.")

        lines.extend(["", "## Recommended reading order", ""])
        lines.append("- `session_summary.csv`: inspect data quality, tier, and runtime status at the sample level.")
        lines.append("- `device_model_summary.csv`: inspect model-level concentration and stability.")
        lines.append("- `event_timeline.csv`: inspect trigger, transition, and session timing.")
        lines.append("- `flagged_sessions.csv`: inspect fallback samples, missing fields, and heavy downgrade cases.")
        lines.append("- `parse_issues.csv`: inspect malformed files or unsupported payloads.")
        return "\n".join(lines) + "\n"


def _maybe_dict_value(value: Any, key: str) -> Any:
    if isinstance(value, dict):
        return value.get(key)
    return None


def discover_input_files(input_paths: Iterable[Path], output_dir: Path) -> list[Path]:
    files: list[Path] = []
    resolved_output = output_dir.resolve()
    for input_path in input_paths:
        resolved_input = input_path.resolve()
        if resolved_input.is_file():
            if resolved_input.suffix.lower() in SUPPORTED_SUFFIXES and not _is_within(
                resolved_input, resolved_output
            ):
                files.append(resolved_input)
            continue
        if not resolved_input.exists():
            continue
        for candidate in resolved_input.rglob("*"):
            if not candidate.is_file():
                continue
            if candidate.suffix.lower() not in SUPPORTED_SUFFIXES:
                continue
            if _is_within(candidate.resolve(), resolved_output):
                continue
            files.append(candidate.resolve())
    return files


def _is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze Flutter performance tier diagnostics JSON and structured logs."
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        help="Input file or directory. Supports .json/.jsonl/.ndjson/.log/.txt",
    )
    parser.add_argument(
        "--output",
        default="build/diagnostics_analysis",
        help="Output directory for CSV and Markdown files.",
    )
    parser.add_argument(
        "--prefix",
        default="PERF_TIER_LOG",
        help="Structured log prefix used in text logs.",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=10,
        help="Top-N rows to include in the Markdown summary sections.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output).resolve()
    files = discover_input_files((Path(item) for item in args.inputs), output_dir)
    if not files:
        print("No supported input files found.")
        return 1

    analyzer = DiagnosticsAnalyzer(prefix=args.prefix, top_n=max(args.top, 1))
    analyzer.ingest_files(files)
    analyzer.write_outputs(output_dir)

    print(f"Analyzed {analyzer.files_scanned} files.")
    print(f"Session rows: {len(analyzer.session_rows)}")
    print(f"Structured log events: {len(analyzer.event_rows)}")
    print(f"Parse issues: {len(analyzer.issues)}")
    print(f"Output directory: {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
