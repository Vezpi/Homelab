"""Offline Ansible control-flow smoke tests; no Proxmox connection is made."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from proxmoxer.backends.https import ProxmoxHTTPApiTokenAuth
from requests import Request

ROOT = Path(__file__).resolve().parents[1]
PLAYBOOK = ROOT.parents[1] / "provision_vm.yml"
COLLECTION = "community/proxmox/plugins/modules"
MOCK = '''#!/usr/bin/python
import json
import os
from ansible.module_utils.basic import AnsibleModule

kind = __file__.rsplit('/', 1)[-1].removesuffix('.py')
fields = ('api_host', 'api_port', 'api_user', 'api_token_id', 'api_token_secret',
          'validate_certs', 'vmid', 'node', 'type', 'config', 'clone', 'newid',
          'name', 'storage', 'full', 'update', 'update_unsafe', 'cores',
          'memory', 'net', 'ipconfig', 'ciuser', 'sshkeys', 'state', 'disk', 'size')
module = AnsibleModule(argument_spec={key: dict(type='raw') for key in fields})
p = module.params
with open(os.environ['MOCK_LOG'], 'a', encoding='utf-8') as log:
    log.write(json.dumps({'kind': kind, 'state': p['state'],
                          'api_user': p['api_user'], 'api_token_id': p['api_token_id'],
                          'vmid': p['vmid'], 'newid': p['newid'],
                          'name': p['name'], 'cores': p['cores'], 'memory': p['memory'],
                          'disk': p['disk'], 'size': p['size'],
                          'net': p['net'], 'ipconfig': p['ipconfig']}) + '\\n')
scenario = os.environ['MOCK_SCENARIO']
if kind == 'proxmox_vm_info':
    if p['vmid'] == 900:
        module.exit_json(changed=False, proxmox_vms=[{
            'node': 'example-node', 'template': True,
            'config': {'scsi0': 'store:vm-900-disk-0,size=2G',
                       'scsi1': 'store:cloudinit'}}])
    module.exit_json(changed=False, proxmox_vms=[{'vmid': 250}] if scenario == 'collision' else [])
if scenario == 'clone_failure' and p['clone']:
    module.fail_json(msg='simulated clone failure')
if scenario == 'allocation_failure' and p['clone']:
    module.fail_json(msg='unable to retrieve next free vmid')
if scenario == 'race' and p['clone']:
    module.exit_json(changed=False)
if scenario == 'missing_id' and p['clone']:
    module.exit_json(changed=True)
module.exit_json(changed=True, vmid=(99 if scenario == 'invalid_id' else 250) if p['clone'] else p['vmid'])
'''


class ProvisionFlow(unittest.TestCase):
    def run_scenario(self, scenario, overrides=None):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            modules = path / 'ansible_collections' / COLLECTION
            modules.mkdir(parents=True)
            meta = modules.parent.parent / 'meta'
            meta.mkdir()
            (meta / 'runtime.yml').write_text(
                'action_groups:\n  proxmox:\n    - proxmox_vm_info\n'
                '    - proxmox_kvm\n    - proxmox_disk\n', encoding='utf-8')
            for name in ('proxmox_vm_info', 'proxmox_kvm', 'proxmox_disk'):
                (modules / f'{name}.py').write_text(MOCK, encoding='utf-8')
            log = path / 'calls.jsonl'
            env = dict(os.environ,
                       ANSIBLE_COLLECTIONS_PATH=str(path),
                       ANSIBLE_LOCAL_TEMP=str(path / 'local'),
                       MOCK_LOG=str(log), MOCK_SCENARIO=scenario)
            variables = dict(proxmox_api_host='example.invalid',
                             proxmox_api_token_id='offline@pam!test',
                             proxmox_api_token_secret='not-a-real-secret',
                             proxmox_node='example-node', vm_template_id=900,
                             vm_hostname='test-vm', vm_storage='store', vm_user='testuser',
                             vm_ssh_public_key='ssh-ed25519 AAAAoffline test')
            variables.update(overrides or {})
            result = subprocess.run(
                ['ansible-playbook', '-i', 'localhost,', '-c', 'local',
                 str(PLAYBOOK), '-e', json.dumps(variables)],
                env=env, capture_output=True, text=True, check=False)
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, calls

    def test_collision_stops_before_any_write(self):
        result, calls = self.run_scenario('collision')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('already exists', result.stdout)
        self.assertEqual([c['kind'] for c in calls], ['proxmox_vm_info'])

    def test_success_configures_before_start(self):
        result, calls = self.run_scenario('success')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([(c['kind'], c['state']) for c in calls], [
            ('proxmox_vm_info', None), ('proxmox_vm_info', None),
            ('proxmox_kvm', 'present'), ('proxmox_kvm', 'present'),
            ('proxmox_disk', 'resized'), ('proxmox_kvm', 'started')])
        self.assertEqual(calls[2]['vmid'], 900)
        self.assertIsNone(calls[2]['newid'])
        self.assertEqual(calls[3]['net'], {'net0': 'virtio,bridge=vlan66'})
        self.assertEqual(calls[2]['name'], 'test-vm')
        self.assertEqual(calls[3]['memory'], 2048)
        self.assertEqual(calls[3]['cores'], 1)
        self.assertEqual(calls[3]['ipconfig'], {'ipconfig0': 'ip=dhcp'})
        self.assertEqual((calls[4]['disk'], calls[4]['size']), ('scsi0', '4G'))
        self.assertEqual(calls[5]['vmid'], 250)

    def test_survey_values_convert_and_map(self):
        result, calls = self.run_scenario('success', dict(vm_hostname='new-vm', vm_cpu=4,
            vm_ram_gib=3, vm_disk_gib=9, vm_vlan='vlan88'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls[3]['memory'], 3072)
        self.assertEqual(calls[3]['cores'], 4)
        self.assertEqual(calls[3]['net'], {'net0': 'virtio,bridge=vlan88'})
        self.assertEqual(calls[4]['size'], '9G')

    def test_invalid_allocated_vmid_stops_before_configuration(self):
        result, calls = self.run_scenario('invalid_id')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([c['kind'] for c in calls], [
            'proxmox_vm_info', 'proxmox_vm_info', 'proxmox_kvm'])

    def test_missing_allocated_vmid_stops_before_configuration(self):
        result, calls = self.run_scenario('missing_id')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([c['kind'] for c in calls], [
            'proxmox_vm_info', 'proxmox_vm_info', 'proxmox_kvm'])

    def test_allocation_failure_stops_before_configuration(self):
        result, calls = self.run_scenario('allocation_failure')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([c['kind'] for c in calls], [
            'proxmox_vm_info', 'proxmox_vm_info', 'proxmox_kvm'])

    def test_invalid_survey_stops_before_api(self):
        result, calls = self.run_scenario('success', {'vm_ram_gib': 0})
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(calls, [])

    def test_token_id_maps_to_proxmoxer_auth_identity(self):
        result, calls = self.run_scenario('success')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(calls)
        for call in calls:
            self.assertEqual(
                (call['api_user'], call['api_token_id']),
                ('offline@pam', 'test'),
            )
            request = Request('GET', 'https://example.invalid/').prepare()
            ProxmoxHTTPApiTokenAuth(
                call['api_user'], call['api_token_id'], 'synthetic-value',
            )(request)
            self.assertEqual(
                request.headers['Authorization'],
                'PVEAPIToken=offline@pam!test=synthetic-value',
            )

    def test_clone_noop_stops_before_configuration(self):
        result, calls = self.run_scenario('race')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([c['kind'] for c in calls], [
            'proxmox_vm_info', 'proxmox_vm_info', 'proxmox_kvm'])

    def test_clone_failure_stops_before_configuration(self):
        result, calls = self.run_scenario('clone_failure')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([c['kind'] for c in calls], [
            'proxmox_vm_info', 'proxmox_vm_info', 'proxmox_kvm'])


if __name__ == '__main__':
    unittest.main()
