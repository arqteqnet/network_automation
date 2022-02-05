# Ansible Tooling to Automate Juniper Hardware. This is leveraging the Juniper Community Ansible Modules
Click here for link to [Ansible Juniper Modules](https://junos-ansible-modules.readthedocs.io/en/2.4.0/)

Click here for link to [Ansible Automation Documentation](https://docs.ansible.com/ansible/latest/index.html) 


## Playbooks

This repo contains a playbook called ![juniper_automation_playbook](juniper_automation_playbook.yml).
The playbook can be created in many different ways, some examples listed below

- using multiple child playbooks and importing them into a parent play.
- using a single playbook but importing multiple "roles" into the playbook
- leveraging child and parent playbooks within a role, and then importing multiple roles into the playbook.


## Roles

Roles are defined in two ways in this project:
- Community Galaxy modules that are being imported, such as the Juniper Junos Modules.
- Custom Modules created by the user


## Tags

Tags are a useful tooling for the following reasons:
- Ensure a task **Always** runs
- Ensures a task **Never** runs
- Groups together playlists and roles for logical groupings

Two examples are below of typical usage.

- Tags applied to Roles

```
- name: My Playbook
  hosts:
    - juniper
  roles:
    - { role: Juniper.junos, tags: [ always ] } #External Module, Always run
    - { role: config_setup_commit,  tags: [ always ] } #Internal module, Always runs
    - juniper_automtion_templates #Internal Module, no tags applied
```

- Tags applied to Tasks

```
 tasks:

    - name: Diff of Config Merge
      tags: [ never, diff_merge ]
```


## Inventory file and VAR inheritance

There are many ways to inherit variables, the most popular ones being below.


### DEFAULTS

```
cat defaults/main.yml
---
system:
  ssh_version: v2
```


### GROUP

```
ansible-inventories
├── group_vars
│   ├── all
│   │   ├── default.yml
│   ├── firewalls
│   │   └── prod_firewalls.yml
│   ├── DC
│   │   └── dc0.yml
│   │   └── dc1.yml

```

#### Multiple Group Inheritance with group_vars Groupings in inventory file 
```
cat inventory 
[all]
dc0_msw0
dc0_sfw
dc1_sfw
dc1_mfw

[prod_firewalls]
dc0_sfw
dc1_sfw

[DC0]
dc0_sfw
dc0_msw0

[DC1]
dc1_sfw
dc1_mfw
```


### HOST

```
ansible-inventories
├── group_vars
│   ├── [...]
├── host_vars
│   ├── fw0.yml
│   ├── router0.yml
```


### PLAYBOOKS

```
- hosts: router0
  vars:
    fxp0: 172.16.255.12/24
```


### VARS (constants which override all values)

```
cat vars/main.yml
---
ssh_root: disabled
```


## Order of Inheritance

```
    Extra vars (from command-line) always win.

    Task vars (only for the specific task).

    Block vars (only for the tasks within the block).

    Role and include vars.

    Vars created with set_fact.

    Vars created with the register task directive.

    Play vars_files.

    Play vars_prompt.

    Play vars.

    Host facts.

    Playbook host_vars.

    Playbook group_vars.

    Inventory host_vars.

    Inventory group_vars.

    Inventory vars.

    Role defaults.
```


## Prerequisites

* Python packages installed to retrieve secrets from Vault and allow Juniper.Junos role to work
  ```
  pip install -r pip_requirements.txt
  ```

* Environment Variable exported to host for Vault
  ```
  export VAULT_ADDR='https://vault_fqdn:8200'
  ``` 

* You will now need to login to VAULT; using the following command:
  ```
  vault login -method=ldap username=<your username>
  ```
* You need to install Juniper Junos roles, this can be done by executing:
  ```
  ansible-galaxy install -r ansible_requirements.yml
  ```

* User with read and write privileges on Juniper Devices

* Netconf Access to remote Devices



## Usage


### Inventory File

Default location of inventory file is on local host at `/etc/ansible/hosts`

```
ansible-playbook -i inventory
```


### Limit Hosts

```
ansible-playbook --limit=myhost
```

### Register Diff and output during the Play
```
ansible-playbook --diff
```


### Utilise Tags
These can be combined with multiple tags

```
ansible-playbook -t mytag0 -t mytag1 -t mytag2
```


### Tags Examples
```
- never (built in tag, that ensures a task is not run. Can be overriden if if another tag is called)

- always (built in tag that ensures a task always runs)

- diff_merge (provides a Merge Diff with selected tags (eg system, ntp, all) and exits without making any changes)

- diff_override (provides a Override Diff with ALL rendered config files)

- merge (merges the config into the Juniper using a 5 minute rollback)

- override (overrides entire config on Juniper device, with 5 minute rollback.)

- system (system level config parameters)

- interfaces (interface level config)

- security_policies
```


### Putting it all together
```
 ansible-playbook my_playbook.yml --diff -i inventory --limit=myhost -t merge_diff -t interfaces
```


### Default Action of Tooling.

* Due to how dangerous automation can be for Networking Hardware, it has built in failsafes

* Changes always force a Check of the Syntax with the Juniper Device

* Configuration file is not uploaded to any device without explicitly defining one of the tags

* Without a terminating tag called, the playbook will exit after rendering all partial config files


### Playbook output Examples

* `ansible-playbook juniper_automation_playbook.yml --limit=dc0_sfw -i inventory` 
   ![Playbook No Tags](examples/playbook_notags)

* `ansible-playbook juniper_automation_playbook.yml --limit=dc0_sfw -i inventory --diff -t diff_merge -t users` 
   ![Playbook Diff Merge](examples/playbook_diff_merge)

* `ansible-playbook juniper_automation_playbook.yml --limit=dc0_sfw -i inventory --diff -t diff_override` 
   ![Playbook Diff Override](examples/playbook_diff_override)

