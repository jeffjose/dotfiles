# Ansible commands

## Limit running to one host
Limit running on host `ansible-test`

```shell
ansible-playbook main.yml --vault-pass-file /tmp/pass  --limit ansible-test
```
