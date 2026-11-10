import importlib.util
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "dst_wrapper_audit.py"
SPEC = importlib.util.spec_from_file_location("dst_wrapper_audit", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DstWrapperAuditTests(unittest.TestCase):
    def finding(self, source):
        result = MODULE.analyze_source("modmain.lua", source)
        self.assertIsNone(result["parse_error"])
        self.assertEqual(len(result["findings"]), 1)
        return result["findings"][0]

    def test_cooperative_wrapper_returns_previous_results(self):
        finding = self.finding("""
AddComponentPostInit("health", function(self)
    local old_setval = self.SetVal
    self.SetVal = function(self, val, cause)
        return old_setval(self, val, cause)
    end
end)
""")
        self.assertEqual(finding["target"], "self.SetVal")
        self.assertEqual(finding["delegation"], "delegation_found")
        self.assertEqual(finding["return_handling"], "previous_call_is_last_return_expression")
        self.assertEqual(finding["argument_evidence"]["self_forwarded_as_first_argument"], True)

    def test_capture_without_delegation_is_flagged(self):
        finding = self.finding("""
local old_update = component.Update
component.Update = function(self, dt)
    self.counter = self.counter + dt
end
""")
        self.assertEqual(finding["delegation"], "no_delegation_found")
        self.assertEqual(finding["severity"], "high")

    def test_previous_call_without_return_is_flagged_for_review(self):
        finding = self.finding("""
local old_get = object.GetValue
object.GetValue = function(self)
    old_get(self)
    return self.cached
end
""")
        self.assertEqual(finding["return_handling"], "previous_call_not_directly_returned")

    def test_varargs_forwarded(self):
        finding = self.finding("""
local old_attack = combat.DoAttack
combat.DoAttack = function(self, target, ...)
    return old_attack(self, target, ...)
end
""")
        self.assertEqual(finding["argument_evidence"]["vararg_forwarding"], "forwarded")

    def test_varargs_not_forwarded(self):
        finding = self.finding("""
local old_attack = combat.DoAttack
combat.DoAttack = function(self, target, ...)
    return old_attack(self, target)
end
""")
        self.assertEqual(
            finding["argument_evidence"]["vararg_forwarding"],
            "not_forwarded_in_this_call",
        )

    def test_missing_self_is_visible(self):
        finding = self.finding("""
local old_set = self.SetVal
self.SetVal = function(self, value)
    return old_set(value)
end
""")
        self.assertFalse(finding["argument_evidence"]["self_forwarded_as_first_argument"])

    def test_nested_closure_call_is_not_misclassified_as_direct_delegation(self):
        finding = self.finding("""
local old_tick = inst.OnUpdate
inst.OnUpdate = function(self, dt)
    self.task = function()
        old_tick(self, dt)
    end
end
""")
        self.assertEqual(finding["delegation"], "no_delegation_found")

    def test_conditional_delegation_is_marked_as_conditional(self):
        finding = self.finding("""
local old_fn = obj.Method
obj.Method = function(self, value)
    if self.enabled then
        return old_fn(self, value)
    end
    return false
end
""")
        self.assertTrue(finding["control_flow_contains_conditionals"])

    def test_single_captured_result_return_flags_possible_tuple_truncation(self):
        finding = self.finding("""
local old_calc = combat.CalcDamage
combat.CalcDamage = function(self, target, weapon, multiplier)
    local damage = old_calc(self, target, weapon, multiplier)
    return damage
end
""")
        self.assertEqual(
            finding["return_handling"],
            "captured_single_result_then_returned_possible_tuple_truncation",
        )
        self.assertTrue(
            finding["captured_result_evidence"][0]["possible_multi_return_truncation"]
        )

    def test_multiple_captured_results_returned_are_recognized(self):
        finding = self.finding("""
local old_calc = combat.CalcDamage
combat.CalcDamage = function(self, target, weapon, multiplier)
    local damage, spdamage = old_calc(self, target, weapon, multiplier)
    return damage, spdamage
end
""")
        self.assertEqual(
            finding["return_handling"],
            "captured_multiple_results_then_returned",
        )
        self.assertFalse(
            finding["captured_result_evidence"][0]["possible_multi_return_truncation"]
        )

    def test_colon_method_includes_implicit_self_parameter(self):
        finding = self.finding("""
local old_method = obj.Method
function obj:Method(value)
    return old_method(self, value)
end
""")
        self.assertEqual(
            finding["argument_evidence"]["wrapper_parameters"],
            ["self", "value"],
        )
        self.assertTrue(finding["argument_evidence"]["self_forwarded_as_first_argument"])

    def test_dst_doattack_wrapper_reports_missing_optional_parameters(self):
        finding = self.finding("""
local old_attack = combat.DoAttack
function combat:DoAttack(target, weapon, projectile, stimuli, instancemult)
    old_attack(self, target, weapon, projectile, stimuli, instancemult)
end
""")
        contract = finding["api_contract_evidence"]
        self.assertEqual(contract["missing_trailing_parameter_count"], 2)
        self.assertEqual(contract["parameter_arity_risk"], "possible_trailing_argument_loss")

    def test_dst_getattacked_wrapper_reports_missing_spdamage_parameter(self):
        finding = self.finding("""
local old_attacked = combat.GetAttacked
function combat:GetAttacked(attacker, damage, weapon, stimuli)
    return old_attacked(self, attacker, damage, weapon, stimuli)
end
""")
        contract = finding["api_contract_evidence"]
        self.assertEqual(contract["missing_trailing_parameter_count"], 1)
        self.assertEqual(contract["parameter_arity_risk"], "possible_trailing_argument_loss")

    def test_dst_calcdamage_contract_reports_possible_second_return_loss(self):
        finding = self.finding("""
local old_calc = combat.CalcDamage
function combat:CalcDamage(target, weapon, multiplier)
    local damage = old_calc(self, target, weapon, multiplier)
    return damage
end
""")
        contract = finding["api_contract_evidence"]
        self.assertEqual(contract["expected_return_count"], 2)
        self.assertEqual(contract["return_arity_risk"], "possible_multi_return_truncation")

    def test_dst_doareaattack_direct_override_reports_missing_onlyontarget(self):
        result = MODULE.analyze_source("modmain.lua", """
AddComponentPostInit("combat", function(self)
    function self:DoAreaAttack(target, range, weapon, validfn, stimuli, excludetags)
        return 0
    end
end)
""")
        self.assertIsNone(result["parse_error"])
        finding = next(
            item for item in result["findings"]
            if item["target"] == "self.DoAreaAttack"
        )
        self.assertEqual(
            finding["delegation"],
            "no_previous_function_capture_found_in_same_block",
        )
        self.assertEqual(
            finding["api_contract_evidence"]["missing_trailing_parameter_count"],
            1,
        )

    def test_unrelated_assignment_is_not_a_wrapper(self):
        result = MODULE.analyze_source(
            "modmain.lua",
            "object.Method = function(self) return true end\n",
        )
        self.assertEqual(result["findings"], [])

    def test_alias_capture_in_different_block_is_not_paired(self):
        result = MODULE.analyze_source("modmain.lua", """
do
    local old_fn = obj.Method
end
obj.Method = function(self)
    return true
end
""")
        self.assertEqual(result["findings"], [])


if __name__ == "__main__":
    unittest.main()
