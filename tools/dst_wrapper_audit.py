#!/usr/bin/env python3
"""Read-only Lua wrapper-chain triage using a Lua 5.1-compatible AST parser.

The analyzer never executes scanned Lua. Findings are static candidates, not proof
of runtime behavior, call order, or API-contract violations.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    from luaparser import ast
    from luaparser import astnodes
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "AST analysis requires the optional dependency: "
        "python -m pip install -r tools/requirements-audit-ast.txt"
    ) from exc

TOOLS_DIR = str(Path(__file__).resolve().parent)
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)
from dst_mod_audit import decode_text, source_entries  # noqa: E402

MAX_AST_FILE_BYTES = 2 * 1024 * 1024
MAX_AST_TOTAL_BYTES = 32 * 1024 * 1024
FUNCTION_NODE_NAMES = {"AnonymousFunction", "Function", "Method", "LocalFunction", "GlobalFunction"}
CONTROL_NODE_NAMES = {"If", "ElseIf", "While", "Repeat", "Fornum", "Forin"}

# Signature snapshots from the public DST combat.lua mirror inspected on 2026-11-10.
# These are comparison hints, not a guarantee for every installed DST build.
DST_PUBLIC_API_CONTRACTS = {
    "CalcDamage": {
        "parameters": ["self", "target", "weapon", "multiplier"],
        "return_count": 2,
        "returns": ["damage", "spdamage"],
        "source": "https://github.com/vietnd69/dst-scripts/blob/main/components/combat.lua",
    },
    "DoAttack": {
        "parameters": [
            "self", "targ", "weapon", "projectile", "stimuli",
            "instancemult", "instrangeoverride", "instpos",
        ],
        "source": "https://github.com/vietnd69/dst-scripts/blob/main/components/combat.lua",
    },
    "GetAttacked": {
        "parameters": ["self", "attacker", "damage", "weapon", "stimuli", "spdamage"],
        "source": "https://github.com/vietnd69/dst-scripts/blob/main/components/combat.lua",
    },
    "DoAreaAttack": {
        "parameters": [
            "self", "target", "range", "weapon", "validfn",
            "stimuli", "excludetags", "onlyontarget",
        ],
        "return_count": 1,
        "returns": ["hitcount"],
        "source": "https://github.com/vietnd69/dst-scripts/blob/main/components/combat.lua",
    },
}


def _children(node):
    if not isinstance(node, astnodes.Node):
        return
    for value in vars(node).values():
        if isinstance(value, astnodes.Node):
            yield value
        elif isinstance(value, (list, tuple)):
            for item in value:
                if isinstance(item, astnodes.Node):
                    yield item


def walk(node, *, stop_at_nested_functions=False, root=True):
    if not isinstance(node, astnodes.Node):
        return
    yield node
    if stop_at_nested_functions and not root and type(node).__name__ in FUNCTION_NODE_NAMES:
        return
    for child in _children(node):
        yield from walk(child, stop_at_nested_functions=stop_at_nested_functions, root=False)


def _name(node):
    return getattr(node, "id", None) if type(node).__name__ == "Name" else None


def _member_target(node):
    if type(node).__name__ != "Index":
        return None
    receiver, member = _name(getattr(node, "value", None)), _name(getattr(node, "idx", None))
    return f"{receiver}.{member}" if receiver and member else None


def _line(node):
    return getattr(node, "line", None)


def _is_alias_call(node, alias):
    return (
        type(node).__name__ in {"Call", "Invoke"}
        and _name(getattr(node, "func", None)) == alias
    )


def _call_nodes(function_body, alias):
    return [
        node for node in walk(function_body, stop_at_nested_functions=True)
        if _is_alias_call(node, alias)
    ]


def _direct_return_positions(function_body, alias):
    positions = []
    for node in walk(function_body, stop_at_nested_functions=True):
        if type(node).__name__ != "Return":
            continue
        values = list(getattr(node, "values", []) or [])
        for index, value in enumerate(values):
            if _is_alias_call(value, alias):
                positions.append({
                    "line": _line(node),
                    "value_index": index,
                    "is_last_return_expression": index == len(values) - 1,
                })
    return positions


def _function_parameters(function_node):
    args = list(getattr(function_node, "args", []) or [])
    names = [_name(arg) for arg in args if _name(arg)]
    # Lua's colon method syntax inserts an implicit first parameter named self.
    if type(function_node).__name__ == "Method":
        names.insert(0, "self")
    has_varargs = any(type(arg).__name__ in {"Dots", "Varargs"} for arg in args)
    return names, has_varargs


def _captured_result_evidence(function_body, alias):
    """Track simple local/assignment capture of a previous call into return values."""
    evidence = []
    for node in walk(function_body, stop_at_nested_functions=True):
        if type(node).__name__ not in {"LocalAssign", "Assign"}:
            continue
        targets = list(getattr(node, "targets", []) or [])
        values = list(getattr(node, "values", []) or [])
        for value_index, value in enumerate(values):
            if not _is_alias_call(value, alias) or not targets:
                continue
            # Lua expands only the final RHS call into the remaining target slots.
            if value_index == len(values) - 1:
                captured_targets = targets[value_index:]
            else:
                captured_targets = targets[value_index:value_index + 1]
            captured_names = [_name(target) for target in captured_targets]
            captured_names = [name for name in captured_names if name]
            if not captured_names:
                continue
            for ret in walk(function_body, stop_at_nested_functions=True):
                if type(ret).__name__ != "Return":
                    continue
                return_names = [_name(item) for item in (getattr(ret, "values", []) or [])]
                return_names = [name for name in return_names if name]
                cursor = -1
                returned_names = []
                for name in captured_names:
                    try:
                        cursor = return_names.index(name, cursor + 1)
                        returned_names.append(name)
                    except ValueError:
                        break
                if len(returned_names) == len(captured_names):
                    handling = (
                        "captured_single_result_then_returned"
                        if len(captured_names) == 1
                        else "captured_multiple_results_then_returned"
                    )
                elif returned_names:
                    handling = "captured_result_partially_returned"
                else:
                    handling = "captured_result_not_found_in_return"
                evidence.append({
                    "capture_line": _line(node),
                    "call_line": _line(value),
                    "captured_target_names": captured_names,
                    "return_line": _line(ret),
                    "return_names": return_names,
                    "returned_captured_names": returned_names,
                    "handling": handling,
                    "possible_multi_return_truncation": (
                        len(captured_names) == 1 or
                        len(returned_names) < len(captured_names)
                    ),
                })
    return evidence


def _argument_evidence(function_node, call_node):
    parameter_names, wrapper_has_varargs = _function_parameters(function_node)
    call_args = list(getattr(call_node, "args", []) or [])
    forwarded_names = [_name(arg) for arg in call_args if _name(arg)]
    call_has_varargs = any(type(arg).__name__ in {"Dots", "Varargs"} for arg in call_args)
    self_forwarded = None
    if parameter_names and parameter_names[0] == "self":
        self_forwarded = bool(call_args and _name(call_args[0]) == "self")
    missing_names = [name for name in parameter_names if name not in forwarded_names]
    if wrapper_has_varargs and call_has_varargs:
        vararg_status = "forwarded"
    elif wrapper_has_varargs:
        vararg_status = "not_forwarded_in_this_call"
    else:
        vararg_status = "not_applicable_or_unknown"
    return {
        "wrapper_parameters": parameter_names,
        "wrapper_accepts_varargs": wrapper_has_varargs,
        "call_argument_names": forwarded_names,
        "call_forwards_varargs": call_has_varargs,
        "parameter_names_not_seen_as_direct_arguments": missing_names,
        "self_forwarded_as_first_argument": self_forwarded,
        "vararg_forwarding": vararg_status,
        "interpretation": (
            "Argument names are syntactic evidence only. Transformed values, defaults, "
            "captured variables, and API-specific optional parameters require manual review."
        ),
    }


def _api_contract_evidence(target, function_node, captured_results, returns):
    method_name = target.rsplit(".", 1)[-1]
    contract = DST_PUBLIC_API_CONTRACTS.get(method_name)
    if contract is None:
        return None
    parameters, has_varargs = _function_parameters(function_node)
    expected_parameters = contract["parameters"]
    missing_count = max(0, len(expected_parameters) - len(parameters))
    result = {
        "profile": "public_dst_combat_lua_mirror_2026-11-10",
        "source": contract["source"],
        "expected_parameter_count_including_self": len(expected_parameters),
        "observed_wrapper_parameter_count_including_self": len(parameters),
        "missing_trailing_parameter_count": missing_count,
        "wrapper_accepts_varargs": has_varargs,
        "parameter_arity_risk": (
            "possible_trailing_argument_loss"
            if missing_count and not has_varargs else
            "varargs_may_accept_trailing_arguments"
            if missing_count and has_varargs else
            "parameter_count_matches_profile"
        ),
    }
    if "return_count" in contract:
        result["expected_return_count"] = contract["return_count"]
        result["expected_return_names"] = contract["returns"]
        if any(
            item["handling"] == "captured_single_result_then_returned"
            for item in captured_results
        ) and contract["return_count"] > 1:
            result["return_arity_risk"] = "possible_multi_return_truncation"
        elif returns:
            result["return_arity_risk"] = "direct_return_detected_review_control_flow"
        else:
            result["return_arity_risk"] = "not_determined"
    return result


def _analyze_wrapper(path, target, capture, alias, function_node, body):
    calls = _call_nodes(body, alias)
    returns = _direct_return_positions(body, alias)
    captured_results = _captured_result_evidence(body, alias)
    conditional = any(
        type(node).__name__ in CONTROL_NODE_NAMES
        for node in walk(body, stop_at_nested_functions=True)
    )
    if not calls:
        delegation, return_handling, severity, argument_evidence = (
            "no_delegation_found", "no_previous_function_call", "high", None
        )
    else:
        delegation, severity = "delegation_found", "review"
        last_returned = any(item["is_last_return_expression"] for item in returns)
        nonfinal_returned = any(not item["is_last_return_expression"] for item in returns)
        if last_returned:
            return_handling = "previous_call_is_last_return_expression"
        elif nonfinal_returned:
            return_handling = "previous_call_is_nonfinal_return_expression"
        elif any(item["handling"] == "captured_multiple_results_then_returned" for item in captured_results):
            return_handling = "captured_multiple_results_then_returned"
        elif any(item["handling"] == "captured_single_result_then_returned" for item in captured_results):
            return_handling = "captured_single_result_then_returned_possible_tuple_truncation"
        elif captured_results:
            return_handling = captured_results[0]["handling"]
        else:
            return_handling = "previous_call_not_directly_returned"
        argument_evidence = _argument_evidence(function_node, calls[0])
    api_contract = _api_contract_evidence(target, function_node, captured_results, returns)
    return {
        "path": path,
        "target": target,
        "captured_alias": alias,
        "capture_line": capture.get("line"),
        "override_line": _line(function_node),
        "call_lines": [_line(call) for call in calls],
        "direct_return_sites": returns,
        "captured_result_evidence": captured_results,
        "api_contract_evidence": api_contract,
        "delegation": delegation,
        "return_handling": return_handling,
        "control_flow_contains_conditionals": conditional,
        "argument_evidence": argument_evidence,
        "severity": severity,
        "confidence": "medium",
        "analysis_scope": (
            "AST-based, same lexical block capture/override pairing; nested closures are "
            "excluded from call evidence. Full lexical binding and interprocedural flow "
            "are not resolved."
        ),
    }


def _analyze_direct_override(path, target, function_node):
    contract = _api_contract_evidence(target, function_node, [], [])
    parameters, has_varargs = _function_parameters(function_node)
    return {
        "path": path,
        "target": target,
        "captured_alias": None,
        "capture_line": None,
        "override_line": _line(function_node),
        "call_lines": [],
        "direct_return_sites": [],
        "captured_result_evidence": [],
        "api_contract_evidence": contract,
        "delegation": "no_previous_function_capture_found_in_same_block",
        "return_handling": "direct_override_without_detected_chain",
        "control_flow_contains_conditionals": False,
        "argument_evidence": {
            "wrapper_parameters": parameters,
            "wrapper_accepts_varargs": has_varargs,
            "call_argument_names": [],
            "call_forwards_varargs": False,
            "parameter_names_not_seen_as_direct_arguments": [],
            "self_forwarded_as_first_argument": None,
            "vararg_forwarding": "not_applicable",
            "interpretation": "No captured previous function was paired in this lexical block.",
        },
        "severity": "review",
        "confidence": "medium",
        "analysis_scope": (
            "AST-based direct method override candidate. A previous implementation may "
            "exist in another scope/file or be intentionally replaced; runtime behavior is unknown."
        ),
    }


def analyze_source(path: str, source: str) -> dict:
    try:
        tree = ast.parse(source)
    except Exception as exc:
        return {"path": path, "parse_error": str(exc)[:1000], "findings": []}
    findings = []
    for block in (node for node in walk(tree) if type(node).__name__ == "Block"):
        captures, overrides = {}, []
        for statement in list(getattr(block, "body", []) or []):
            kind = type(statement).__name__
            if kind == "LocalAssign":
                targets = list(getattr(statement, "targets", []) or [])
                values = list(getattr(statement, "values", []) or [])
                for target_node, value_node in zip(targets, values):
                    alias, target = _name(target_node), _member_target(value_node)
                    if alias and target:
                        captures[alias] = {"target": target, "line": _line(statement)}
            elif kind == "Assign":
                targets = list(getattr(statement, "targets", []) or [])
                values = list(getattr(statement, "values", []) or [])
                for target_node, value_node in zip(targets, values):
                    target = _member_target(target_node)
                    if target and type(value_node).__name__ == "AnonymousFunction":
                        overrides.append((target, value_node, value_node.body))
            elif kind == "Function":
                target = _member_target(getattr(statement, "name", None))
                if target:
                    overrides.append((target, statement, statement.body))
            elif kind == "Method":
                receiver = _name(getattr(statement, "source", None))
                method_name = _name(getattr(statement, "name", None))
                if receiver and method_name:
                    overrides.append((f"{receiver}.{method_name}", statement, statement.body))
        for target, function_node, body in overrides:
            matching_captures = [
                (alias, capture) for alias, capture in captures.items()
                if capture["target"] == target
            ]
            if matching_captures:
                for alias, capture in matching_captures:
                    findings.append(_analyze_wrapper(
                        path, target, capture, alias, function_node, body
                    ))
            elif target.rsplit(".", 1)[-1] in DST_PUBLIC_API_CONTRACTS:
                findings.append(_analyze_direct_override(path, target, function_node))
    return {"path": path, "parse_error": None, "findings": findings}


def audit(target: Path) -> dict:
    findings, parse_errors, skipped = [], [], []
    total_source_bytes, lua_files = 0, 0
    for name, data, error in source_entries(target):
        if error or data is None or not name.lower().endswith(".lua"):
            continue
        lua_files += 1
        if len(data) > MAX_AST_FILE_BYTES:
            skipped.append({"path": name, "reason": "per-file AST size limit"})
            continue
        if total_source_bytes + len(data) > MAX_AST_TOTAL_BYTES:
            skipped.append({"path": name, "reason": "total AST source size limit"})
            continue
        total_source_bytes += len(data)
        source = decode_text(data)
        if source is None:
            skipped.append({"path": name, "reason": "not decodable as bounded text"})
            continue
        result = analyze_source(name, source)
        if result["parse_error"]:
            parse_errors.append({"path": name, "error": result["parse_error"]})
        findings.extend(result["findings"])
    return {
        "schema": "dst-wrapper-ast-audit/v1",
        "target": str(target),
        "read_only": True,
        "executed_scanned_code": False,
        "parser": "luaparser 4.2.0 (Lua 5.1 grammar default)",
        "lua_file_count": lua_files,
        "parsed_source_bytes": total_source_bytes,
        "wrapper_findings": findings,
        "parse_errors": parse_errors,
        "skipped_files": skipped,
        "interpretation": (
            "AST evidence is a static candidate only. Same-block matching is conservative "
            "but does not fully resolve Lua lexical bindings, control-flow paths, dynamic "
            "targets, runtime load order, or API contracts."
        ),
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", type=Path, help="Mod folder or ZIP archive")
    parser.add_argument("--output", type=Path, help="Write JSON report to this path")
    args = parser.parse_args(argv)
    try:
        report = audit(args.target)
    except (OSError, ValueError) as exc:
        print(f"wrapper audit failed: {exc}", file=sys.stderr)
        return 2
    rendered = json.dumps(report, indent=2, ensure_ascii=False)
    if args.output:
        args.output.write_text(rendered + "\n", encoding="utf-8")
    else:
        print(rendered)
    return 1 if report["parse_errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
