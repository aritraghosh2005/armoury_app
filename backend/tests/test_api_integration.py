import json
import os
import unittest
import urllib.error
import urllib.parse
import urllib.request
import uuid


API_URL = os.environ.get("ARMOURY_TEST_API_URL", "").rstrip("/")


@unittest.skipUnless(API_URL, "set ARMOURY_TEST_API_URL to run the Docker API integration test")
class SharedApiIntegrationTests(unittest.TestCase):
    device_id = "integration-test-device-0001"

    @classmethod
    def setUpClass(cls):
        cls.request(cls, "/v1/auth/devices/register", "POST", {
            "deviceId": cls.device_id, "deviceName": "Integration test device", "platform": "test"
        }, register=True)

    def request(self, path, method="GET", body=None, register=False, headers=None,
                token="armoury-integration-test-token", device_id=None):
        payload = None if body is None else json.dumps(body).encode()
        request_headers = {"Authorization": f"Bearer {token}"}
        if not register:
            request_headers["X-Armoury-Device-ID"] = device_id or self.device_id
        if payload:
            request_headers["Content-Type"] = "application/json"
        request_headers.update(headers or {})
        request = urllib.request.Request(
            f"{API_URL}{path}",
            data=payload,
            method=method,
            headers=request_headers,
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                return response.status, json.loads(response.read())
        except urllib.error.HTTPError as error:
            return error.code, json.loads(error.read())

    def test_shared_add_patch_delete_rules_and_idempotency(self):
        first_id = f"TEST-{uuid.uuid4()}"
        second_id = f"TEST-{uuid.uuid4()}"
        first_create = {
            "id": first_id,
            "operationId": str(uuid.uuid4()),
            "component": {"name": "Motor", "qty": 1, "location": "Crate"},
        }
        status, created = self.request("/v1/components", "POST", first_create)
        self.assertEqual(status, 200)
        status, retried_create = self.request("/v1/components", "POST", first_create)
        self.assertEqual(status, 200)
        self.assertEqual(retried_create["revision"], created["revision"])

        status, second = self.request("/v1/components", "POST", {
            "id": second_id,
            "operationId": str(uuid.uuid4()),
            "component": {"name": "Sensor", "qty": 2},
        })
        self.assertEqual(status, 200)
        self.assertNotEqual(created["id"], second["id"])

        location_op = str(uuid.uuid4())
        status, location_change = self.request(
            f"/v1/components/{first_id}", "PATCH",
            {"operationId": location_op, "changes": {"location": "Toolkit"}},
        )
        self.assertEqual(status, 200)
        self.assertEqual(location_change["component"]["location"], "Toolkit")
        status, location_retry = self.request(
            f"/v1/components/{first_id}", "PATCH",
            {"operationId": location_op, "changes": {"location": "Toolkit"}},
        )
        self.assertEqual(status, 200)
        self.assertEqual(location_retry["revision"], location_change["revision"])

        status, quantity_change = self.request(
            f"/v1/components/{first_id}", "PATCH",
            {"operationId": str(uuid.uuid4()), "changes": {"qty": 9}},
        )
        self.assertEqual(status, 200)
        self.assertEqual(quantity_change["component"]["location"], "Toolkit")
        self.assertEqual(quantity_change["component"]["qty"], 9)

        status, _ = self.request(
            f"/v1/components/{first_id}", "DELETE",
            {"operationId": str(uuid.uuid4())},
        )
        self.assertEqual(status, 200)
        status, audit = self.request("/v1/audit")
        self.assertEqual(status, 200)
        actions = [entry["action"] for entry in audit["items"]]
        self.assertIn("create", actions)
        self.assertIn("modify", actions)
        self.assertIn("delete", actions)
        self.assertTrue(any(entry["email"] == "integration@example.invalid" for entry in audit["items"]))
        self.assertTrue(all("id" not in entry for entry in audit["items"]))

        status, _ = self.request(
            f"/v1/components/{first_id}", "PATCH",
            {"operationId": str(uuid.uuid4()), "changes": {"name": "Resurrected"}},
        )
        self.assertEqual(status, 410)
        status, _ = self.request("/v1/components", "POST", {
            "id": first_id,
            "operationId": str(uuid.uuid4()),
            "component": {"name": "Resurrected"},
        })
        self.assertEqual(status, 410)

        status, archive = self.request('/v1/archive')
        self.assertEqual(status, 200)
        archived = next(item for item in archive['items'] if item['id'] == first_id)
        self.assertEqual(archived['name'], 'Motor')
        self.assertEqual(archived['qty'], 9)
        self.assertEqual(set(archived), {'id', 'name', 'qty', 'deletedAt'})

        restore_body = {'operationId': str(uuid.uuid4())}
        status, restored = self.request(f'/v1/archive/{first_id}/restore', 'POST', restore_body)
        self.assertEqual(status, 200)
        self.assertFalse(restored['deleted'])
        self.assertGreater(restored['revision'], quantity_change['revision'])
        self.assertEqual(restored['component']['location'], 'Toolkit')
        self.assertEqual(restored['component']['qty'], 9)
        self.assertIn('T', restored['component']['updated'])
        status, restored_retry = self.request(f'/v1/archive/{first_id}/restore', 'POST', restore_body)
        self.assertEqual(status, 200)
        self.assertEqual(restored_retry['revision'], restored['revision'])

        status, _ = self.request(
            f'/v1/components/{second_id}', 'DELETE', {'operationId': str(uuid.uuid4())}
        )
        self.assertEqual(status, 200)
        status, _ = self.request(f'/v1/archive/{second_id}', 'DELETE')
        self.assertEqual(status, 200)
        status, _ = self.request(
            f'/v1/archive/{second_id}/restore', 'POST', {'operationId': str(uuid.uuid4())}
        )
        self.assertEqual(status, 404)

        status, feed = self.request("/v1/changes?since=0&limit=500")
        self.assertEqual(status, 200)
        first_events = [change for change in feed["changes"] if change["id"] == first_id]
        self.assertTrue(any(change['deleted'] for change in first_events))
        self.assertFalse(first_events[-1]['deleted'])
        purged_events = [change for change in feed['changes'] if change['id'] == second_id]
        self.assertTrue(purged_events)
        self.assertTrue(all(change['deleted'] and change['component'] is None for change in purged_events))
        revisions = [change["revision"] for change in feed["changes"]]
        self.assertEqual(revisions, sorted(revisions))

    def test_inventory_endpoints_require_registered_google_identity_and_device(self):
        status, _ = self.request("/v1/changes", headers={"Authorization": ""})
        self.assertEqual(status, 401)
        status, _ = self.request("/v1/changes", headers={
            "Authorization": "Bearer forged-google-token",
            "X-Armoury-Device-ID": "",
        })
        self.assertEqual(status, 401)

    def test_approval_roles_and_single_admin_guard(self):
        token = f"armoury-test:viewer-{uuid.uuid4()}:viewer-{uuid.uuid4()}@example.invalid"
        email = token.rsplit(":", 1)[1]
        device_id = f"viewer-device-{uuid.uuid4()}"
        status, profile = self.request("/v1/auth/devices/register", "POST", {
            "deviceId": device_id, "deviceName": "Viewer phone", "platform": "test"
        }, register=True, token=token)
        self.assertEqual(status, 200)
        self.assertEqual((profile["status"], profile["role"]), ("pending", "viewer"))
        status, _ = self.request("/v1/changes", token=token, device_id=device_id)
        self.assertEqual(status, 403)

        status, users = self.request("/v1/admin/users")
        self.assertEqual(status, 200)
        viewer = next(item for item in users["items"] if item["email"] == email)
        status, approved = self.request(f"/v1/admin/users/{viewer['userId']}", "PATCH",
            {"status": "active", "role": "viewer"})
        self.assertEqual(status, 200)
        self.assertEqual(approved["role"], "viewer")
        status, _ = self.request("/v1/changes", token=token, device_id=device_id)
        self.assertEqual(status, 200)
        status, _ = self.request("/v1/components", "POST", {
            "id": f"VIEWER-{uuid.uuid4()}", "operationId": str(uuid.uuid4()),
            "component": {"name": "Must not write"},
        }, token=token, device_id=device_id)
        self.assertEqual(status, 403)
        status, _ = self.request("/v1/admin/users")
        self.assertEqual(status, 200)
        status, _ = self.request(f"/v1/admin/users/{viewer['userId']}", "PATCH",
            {"status": "disabled", "role": "viewer"}, token=token, device_id=device_id)
        self.assertEqual(status, 403)
        status, _ = self.request(f"/v1/admin/users/{viewer['userId']}", "PATCH",
            {"status": "disabled", "role": "viewer"})
        self.assertEqual(status, 200)
        status, _ = self.request("/v1/changes", token=token, device_id=device_id)
        self.assertEqual(status, 403)

        status, _ = self.request("/v1/admin/users/integration-test-user", "PATCH",
            {"status": "disabled", "role": "editor"})
        self.assertEqual(status, 409)
        status, admin_audit = self.request("/v1/admin/audit")
        self.assertEqual(status, 200)
        approval = next(item for item in admin_audit["items"] if item["targetEmail"] == email)
        self.assertEqual(approval["actorEmail"], "integration@example.invalid")
        status, _ = self.request(f"/v1/admin/users/{viewer['userId']}", "PATCH",
            {"status": "active", "role": "admin"})
        self.assertEqual(status, 422)
if __name__ == "__main__":
    unittest.main()
