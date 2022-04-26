# Ansible commands

## Limit running to one host
Limit running on host `ansible-test`

```shell
ansible-playbook main.yml --vault-pass-file /tmp/pass  --limit ansible-test
```

## Limit to tags
Only run tasks with a specific tag

```shell
ansible-playbook main.yml --vault-pass-file /tmp/pass  --limit ansible-test -t vim
```

## Install role to a specific directory
Install role not to localhost, but to a different directory

```shell
ansible-galaxy install markosamuli.linuxbrew -p roles/
```
