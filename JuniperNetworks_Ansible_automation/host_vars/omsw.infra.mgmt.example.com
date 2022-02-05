---
mgmt:
    iface: vme
    gw: 10.192.100.1
    ip: 10.192.100.184
    mask: 24

snmp:
    description: TOR MGMT Switch
    location: DC 1 Rack 1
    contact: noc@example.com
    interface: vme.0
    community_lists:
        nms:
            - 10.192.100.80/32
    community:
        examplecomm:
            community_lists: nms

system:
    root_password: "{{ lookup('hashi_vault','secret=networking/data/system_secrets/root_passwords:omsw.infra.mgmt.example.com') }}"
    netconf_port: 830


syslog: 10.119.4.35/32

chassis:
    graceful_switchover: True
    aggregated_devices: 23


group_config:
    nodes:
        member0:
            system:
                hostname: omsw.n0.infra.mgmt.example.com

        member1:
            system:
                hostname: omsw.n1.infra.mgmt.example.com

    global_group_apply:
        - member0
        - member1


    groups:
        BM_TRUNK:
            interfaces:
                <*>:
                    logical:
                        - unit: 0
                          family: ethernet-switching
                          port_mode: trunk
                          vlan:
                            - OOB
                            - MGMT
                            - DC1_BM_MGMT
                            - DC1_VM_MGMT

        SUPPORT_INFRA:
            interfaces:
                <*>:
                    logical:
                        - unit: 0
                          family: ethernet-switching
                          port_mode: access
                          vlan:
                            - SUPPORT_INFRA


        MGMT_TRUNK:
            interfaces:
                <*>:
                    logical:
                        - unit: 0
                          family: ethernet-switching
                          port_mode: trunk
                          vlan:
                              - MGMT
                              - SUPPORT_INFRA
                              - DC1_BM_MGMT
                              - DC1_VM_MGMT
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

        BOND1_PARENT:
            interfaces:
                <*>:
                    ether_options:
                        bond_parent: ae0

        BOND2_PARENT:
            interfaces:
                <*>:
                    ether_options:
                        bond_parent: ae1

interfaces:
    interface_range:
        ACCESS:
            member:
                - ge-0/0/14
                - ge-1/0/32
            mber_rnge:
                range0:
                    - ge-0/0/1
                    - ge-0/0/3
                range2:
                    - ge-1/0/1
                    - ge-1/0/4
            unit: 0
            description: "ACCESS PORTS RANGE"
            family: ethernet-switching
            port_mode: access
        NON-ROOT-PORTS:
            mber_rnge:
                range1:
                    - ge-0/0/1
                    - ge-0/0/3
                range2:
                    - ge-1/0/1
                    - ge-1/0/4

    interface:
        ae0:
            phy_description: SPINE UPLINK
            apply_groups:
                - MGMT_TRUNK
                - AGGREGATE_LACP_ACTIVE
        ae1:
            phy_description: BAREMETAL DOWNLINK BOND
            apply_groups:
                - BM_TRUNK
                - AGGREGATE_LACP_ACTIVE


        ge-0/0/0:
            phy_description: BOND1 MEMBER
            apply_groups: BOND1_PARENT
        ge-1/0/0:
            phy_description: BOND1 MEMBER
            apply_groups: BOND1_PARENT

        ge-0/0/4:
            phy_description: BOND2 MEMBER
            apply_groups: BOND2_PARENT
        ge-1/0/43:
            phy_description: BOND2 MEMBER
            apply_groups: BOND2_PARENT


        ge-0/0/14:
            phy_description: pdu3r.infra.mgmt.example.com
            apply_groups: SUPPORT_INFRA

        ge-1/0/32:
            phy_description: pdu3l.infra.mgmt.example.com
            apply_groups: SUPPORT_INFRA

        vme:
            unit:
                - name: 0
                  description: "VIRTUAL CHASSIS MGMT IFACE"
                  family: inet
                  ipv4_address: 10.192.100.184
                  ipv4_mask: 24
        lo0:
            unit:
                - name: 0
                  family: inet
                  ipv4_address: 172.16.1.1
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
    profile: example_com
    bum_type: all
    options:
        iface_drop: 30



prefix_lists_v4:
    EXTERNAL-SYSLOG: 192.168.1.1/32
    MANAGEMENT-HOSTS:
        - 10.192.100.0/24
    ARCHIVAL-ASSETS: 192.168.1.10/32

l2_protocols:
    igmp_snoop_vlans: all
    rstp:
        bridge_priority: 8192
        iface_edge:
            - ACCESS
            - NON-ROOT-PORTS
        iface_no_root: NON-ROOT-PORTS
    lldp:
        iface_enabled: all
