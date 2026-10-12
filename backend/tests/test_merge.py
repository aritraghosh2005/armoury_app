import unittest

from backend.app.merge import apply_component_patch, normalize_component


class ComponentMergeTests(unittest.TestCase):
    def test_concurrent_adds_with_unique_ids_are_independent(self):
        first = normalize_component("COMP-A", {"name": "Motor", "qty": 1})
        second = normalize_component("COMP-B", {"name": "Motor", "qty": 1})

        self.assertEqual(first["id"], "COMP-A")
        self.assertEqual(second["id"], "COMP-B")
        self.assertEqual(first["name"], second["name"])

    def test_patch_updates_latest_component_without_replacing_other_fields(self):
        latest = {
            "id": "COMP-A",
            "name": "Motor",
            "qty": 5,
            "location": "Crate 2",
            "desc": "Latest server description",
        }

        changed = apply_component_patch("COMP-A", latest, {"location": "Toolkit"})

        self.assertEqual(changed["location"], "Toolkit")
        self.assertEqual(changed["qty"], 5)
        self.assertEqual(changed["desc"], "Latest server description")

    def test_later_same_field_operation_applies_to_current_state(self):
        original = {"id": "COMP-A", "name": "Motor", "qty": 1}
        first = apply_component_patch("COMP-A", original, {"qty": 3})
        later = apply_component_patch("COMP-A", first, {"qty": 7})

        self.assertEqual(later["qty"], 7)

    def test_local_component_id_cannot_be_overwritten_by_payload(self):
        result = normalize_component("COMP-A", {"id": "COMP-B", "name": "Motor"})

        self.assertEqual(result["id"], "COMP-A")


if __name__ == "__main__":
    unittest.main()
