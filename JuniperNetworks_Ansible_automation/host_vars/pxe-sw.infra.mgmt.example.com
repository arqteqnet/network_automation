---
mgmt:
    iface: me0
    gw: 10.192.100.1
    ip: 10.192.100.170
    mask: 24

snmp:
    description: PXE Switch
    location: DC 1 Rack 1
    contact: noc@example.com
    interface: me0.0
    community_lists:
        nms:
            -  10.192.100.80/32
    community:
        examplecomm:
            community_lists: nms

system:
    root_password: "{{ lookup('hashi_vault','secret=networking/data/system_secrets/root_passwords:pxe-sw.infra.mgmt.example.com') }}"
    netconf_port: 830


syslog: 10.119.4.35/32
archival: 10.119.4.35/32

chassis:
    graceful_switchover: True
    aggregated_devices: 22


group_config:
    nodes:
        member0:
            system:
                hostname: pxe-sw.n0.infra.mgmt.example.com

        member1:
            system:
                hostname: pxe-sw.n1.infra.mgmt.example.com

    global_group_apply:
        - member0
        - member1


    groups:
        CLOUD_TRUNK:
            interfaces:
                <*>:

                    logical:
                        - unit: 0
                          family: ethernet-switching
                          native_vlan: default
                          port_mode: trunk
                          vlan:
                            - OOB
                            - DC1_BM_MGMT
        MGMT_TRUNK:
            interfaces:
                <*>:
                    logical:
                        - unit: 0
                          family: ethernet-switching
                          port_mode: trunk
                          vlan:
                            - MGMT
                            - OOB

        AGGREGATE_LACP_ACTIVE_SPEED_1G:
            interfaces:
                <*>:
                    bond_ether_options:
                        speed: 1g
                        lacp:
                            lacp_timers: fast

        AGGREGATE_LACP_ACTIVE:
            interfaces:
                <*>:
                    bond_ether_options:
                        lacp:
                            lacp_state: active
                            lacp_timers: fast
        IFACE_SPEED_1G:
            interfaces:
                <*>:
                    speed: 1g

        MGMT_UPLINK_BOND:
            interfaces:
                <*>:
                    ether_options:
                        bond_parent: ae0


interfaces:
    interface_range:
        ACCESS:
            mber_rnge:
                range0:
                    - ge-0/0/3
                    - ge-0/0/46
                range2:
                    - ge-1/0/3
                    - ge-1/0/46
            unit: 0
            description: "ACCESS PORTS RANGE"
            family: ethernet-switching
            port_mode: access
        NON-ROOT-PORTS:
            mber_rnge:
                range1:
                    - ge-0/0/3
                    - ge-0/0/46
                range2:
                    - ge-1/0/3
                    - ge-1/0/46
        PXE:
            mber_rnge:
                range1:
                    - ge-0/0/3
                    - ge-0/0/24
                range2:
                    - ge-1/0/3
                    - ge-1/0/24
            unit: 0
            description: "PXE ACCESS INTERFACE"
            family: ethernet-switching
            vlan: default
        OOB:
            mber_rnge:
                range1:
                    - ge-0/0/25
                    - ge-0/0/46
                range2:
                    - ge-1/0/25
                    - ge-1/0/46
            unit: 0
            description: "OOB ACCESS INTERFACE"
            family: ethernet-switching
            vlan: OOB

    interface:
        ae0:
            phy_description: SPINE SWITCH UPLINK BOND
            apply_groups:
                - MGMT_TRUNK
                - AGGREGATE_LACP_ACTIVE
        ge-0/0/47:
            phy_description: AE0 BOND MEMBER
            apply_groups: MGMT_UPLINK_BOND
        ge-1/0/47:
            phy_description: AE0 BOND MEMBER
            apply_groups: MGMT_UPLINK_BOND

        me0:
            unit:
                - name: 0
                  description: "VIRTUAL CHASSIS MGMT IFACE"
                  family: inet
                  ipv4_address: 10.192.100.170
                  ipv4_mask: 24
        lo0:
            unit:
                - name: 0
                  family: inet
                  ipv4_address: 172.16.1.2
                  ipv4_mask: 32
                  filter_input: CPP


vlans:
    OOB:
        id: 60
    DC1_BM_MGMT:
        id: 12
    DC1_VM_MGMT:
        id: 13
    MGMT:
        id: 2
    SUPPORT_INFRA:
        id: 3


storm_control:
    options:
        iface_drop: 30

virtual_chassis:
    auto_update_software: True
    no_split_detection: True
    members:
        - member: 0
          master_priority: 128
          role: routing-engine
        - member: 1
          master_priority: 255
          role: routing-engine



prefix_lists_v4:
    EXTERNAL-SYSLOG: 192.168.1.1/32
    MANAGEMENT-HOSTS:
        - 10.192.100.0/24
    ARCHIVAL-ASSETS: 192.168.1.10/32

l2_protocols:
    igmp_snoop_vlans: all
    rstp:
        bridge_priority: 32k
        iface_edge:
            - ACCESS
            - NON-ROOT-PORTS
        iface_no_root: NON-ROOT-PORTS
    lldp:
        iface_enabled: all
