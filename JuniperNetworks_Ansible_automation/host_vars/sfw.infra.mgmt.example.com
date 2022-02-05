---
mgmt:
    iface: fxp0
    gw: 10.192.100.1
    ip: 10.192.100.188
    mask: 24

snmp:
    description: sfw.infra.mgmt.example.com
    location: DC1 Rack 1
    contact: noc@example.com
    interface: fxp0.0
    community_lists:
        nms:
            -  10.192.100.80/32
    community:
        examplecomm:
            community_lists: nms

system:
    root_password: "{{ lookup('hashi_vault','secret=networking/data/system_secrets/root_passwords:sfw.infra.mgmt.example.com') }}"
    netconf_port: 830

#facility name possibiities [any authorization daemon dfc explicit-priority external firewall ftp interactive-commands kernel ntp pfe secuity user]
#log_level [ alert any critical emergency error info none warning notice ]
    syslog:
        files:
            messages:
                facility:
                    - name: any
                      log_level: notice
                    - name: daemon
                      log_level: error
                explicit: True
            interactive-commands:
                facility:
                    - name: interactive-commands
                      log_level: any
            authorization:
                facility:
                    - name: authorization
                      log_level: any
            pfe:
                facility:
                    - name: pfe
                      log_level: warning

syslog: 10.192.101.20
archival: 10.192.101.200

syslog_stream:
    src: 10.192.100.188
    profile:
        name: Elastic_search
        format: sd-syslog
        category: all


chassis:
    srx_cluster_options:
        reth_devices: 3
        control_link_recovery: True
        redundancy_groups:
            0:
                node0_priority: 200
                node1_priority: 100

            1:
                node0_priority: 200
                node1_priority: 100
                interface_monitor:
                    - iface: ge-0/0/0
                      weight: 128
                    - iface: ge-0/0/1
                      weight: 128
                    - iface: ge-5/0/0
                      weight: 128
                    - iface: ge-5/0/1
                      weight: 128
            2:
                node0_priority: 200
                node1_priority: 100
                interface_monitor:
                    - iface: xe-0/0/16
                      weight: 128
                    - iface: xe-0/0/17
                      weight: 128
                    - iface: xe-5/0/16
                      weight: 128
                    - iface: xe-5/0/17
                      weight: 128




group_config:
    nodes:
        node0:
            system:
                hostname: sfw.n0.infra.mgmt.example.com
                backup_router:
                    gateway: 10.192.100.1
                    routes:
                        - 10.192.101.0/24
                        - 10.101.0.0/16
            interfaces:
                fxp0:
                    logical:
                        - unit: 0
                          family: inet
                          ipv4_address: 10.192.100.186
                          ipv4_master_only: 10.192.100.188
                          ipv4_mask: 24

        node1:
            system:
                hostname: sfw.n1.infra.mgmt.example.com
                backup_router:
                    gateway: 10.192.100.1
                    routes:
                        - 10.192.101.0/24
                        - 10.101.0.0/16
            interfaces:
                fxp0:
                    logical:
                        - unit: 0
                          family: inet
                          ipv4_address: 10.192.100.187
                          ipv4_master_only: 10.192.100.188
                          ipv4_mask: 24

    global_group_apply:
        - node0
        - node1


    groups:

        SVC_TRUNK:
            interfaces:
                <*>:
                    unit: 0
                    family: ethernet-switching
                    port_mode: trunk
                    vlan: MGMT

        RETH1_SPINE_PEERING:
            interfaces:
                <*>:
                    gigether_options:
                        description: "RETH TO SPINE SWITCHES"
                        reth_parent: reth1

        RETH2_LEAF_PEERING:
            interfaces:
                <*>:
                    gigether_options:
                        description: "RETH TO LEAF SWITCHES"
                        reth_parent: reth2

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


interfaces:

    interface:
        ge-0/0/0:
            phy_description: SPINE INTERPOD TRAFFIC
            apply_groups:
                - RETH1_SPINE_PEERING
        ge-0/0/1:
            phy_description: SPINE INTERPOD TRAFFIC
            apply_groups:
                - RETH1_SPINE_PEERING

        xe-0/0/16:
            phy_description: LEAF PEERING
            apply_groups:
                - RETH2_LEAF_PEERING
        xe-0/0/17:
            phy_description: LEAF PEERING
            apply_groups:
                - RETH2_LEAF_PEERING

        ge-5/0/0:
            phy_description: SPINE INTERPOD TRAFFIC
            apply_groups:
                - RETH1_SPINE_PEERING
        ge-5/0/1:
            phy_description: SPINE INTERPOD TRAFFIC
            apply_groups:
                - RETH1_SPINE_PEERING

        xe-5/0/16:
            phy_description: LEAF PEERING
            apply_groups:
                - RETH2_LEAF_PEERING
        xe-5/0/17:
            phy_description: LEAF PEERING
            apply_groups:
                - RETH2_LEAF_PEERING
        reth1:
            phy_description: SPINE PEERING FOR INTERPOD TRAFFIC
            vlan_tagging: True
            redundant_ether_options:
                redundancy_group: 1
                lacp:
                    lacp_state: active
                    lacp_timers: fast
            unit:
                - name: 10
                  description: ECMP LINK TO BOTH BGR'S
                  vlan_id: 10
                  family: inet
                  ipv4_address: 10.191.255.1
                  ipv4_mask: 29
                  security_zone:

        reth2:
            phy_description: parent peering to core switches
            vlan_tagging: True
            mtu: 9126
            redundant_ether_options:
                redundancy_group: 2
                lacp:
                    lacp_state: active
                    lacp_timers: fast
            unit:
                - name: 47
                  description: CLOUD NET
                  vlan_id: 47
                  family: inet
                  ipv4_address: 10.190.0.1
                  ipv4_mask: 16
                  security_zone: CLOUD
                - name: 48
                  description: CLOUD API NET
                  vlan_id: 48
                  family: inet
                  ipv4_address: 10.192.194.1
                  ipv4_mask: 20
                  security_zone: CLOUD_API
                - name: 49
                  description: DCI LD5 <> THW PRIMARY
                  vlan_id: 49
                  family: inet
                  ipv4_address: 10.192.99.2
                  ipv4_mask: 31
                  filter_input: SELECTIVE_PACKET_FORWARDING
                  security_zone: DMZ
                - name: 50
                  description: DCI LD5 <> THW SECONDARY
                  vlan_id: 50
                  family: inet
                  ipv4_address: 10.192.99.4
                  ipv4_mask: 31
                  filter_input: SELECTIVE_PACKET_FORWARDING
                  security_zone: DMZ
                - name: 51
                  description: HLB Egress
                  vlan_id: 51
                  family: inet
                  ipv4_address: 10.192.10050.1
                  ipv4_mask: 24
                  security_zone: DMZ
                  filter_input: SELECTIVE_PACKET_FORWARDING
                - name: 52
                  description: DMZ Ingress
                  vlan_id: 52
                  family: inet
                  multiple_ipv4_address:
                    - 1.1.11.1/24
                    - 1.1.10.9/29
                  security_zone: DMZ

        lo0:
            unit:
                - name: 0
                  family: inet
                  ipv4_address: 172.16.1.2
                  ipv4_mask: 32
                  filter_input: CPP


routes:
    static:
        CLOUD_DC2:
            net: 10.90.0.0
            prefix: 16
            options:
                gw: 10.192.99.3
                qualified_gw: 10.192.99.5
                preference: 1


prefix_lists_v4:
    EXTERNAL-SYSLOG: 192.168.1.1/32
    MANAGEMENT-HOSTS:
        - 10.192.100.0/24
    ARCHIVAL-ASSETS: 192.168.1.10/32


address_entries:
    global:
        - name: EXMPLE_DC1_UNICAST
          ip: 1.1.10.0
          mask: 24

address_groups:
    global:
        - name: EXAMPLE_PUBLIC
          address:
            - EXAMPLE_DC1_UNICAST

firewall_zones:
    - name: INTERPOD
      system_services:
        - ping
      protocols:
        - bgp
        - bfd
    - name: CLOUD
      system_services:
        - ping
    - name: API
      system_services:
        - ping
    - name: DMZ
      system_services:
        - ping
    - name: ipsec-vpn
      system_services:
        - ping

firewall_policies:
    global:
        - name: INTER_POD_RESOURCES
          dst: APPS
          src:
          - DC1_CLOUD_NET
          - API_NET
          from_zone:
          - CLOUD
          - CLOUD_API
          to_zone: DMZ
          application: IPA
          terminate_action: permit
        - name: DNS_FORWARDING
          dst:
            - DNS_MASQ
            - BIND_SERVERS
          src:
            - BIND_SERVERS
            - DNS_MASQ
          from_zone:
            - CLOUD
            - DMZ
          to_zone:
            - CLOUD
            - DMZ
          application: DNS
          terminate_action: permit

nat_translations:
    source_nat:
        pools:
            INTERPOD:
                address: 1.1.10.254/32
        rule_sets:
            SOUTH_TO_NORTH:
                from_zone:
                    - CLOUD
                    - DMZ
                to_zone: INTERPOD
                rules:
                    CLOUD_HTTP_HTTPS:
                        src_add_name: DC1_CLOUD_NET
                        dst_add: 0.0.0.0/0
                        protocol: tcp
                        application:
                            - junos-http
                            - junos-https
                        nat_pool: INTERPOD
                    CLOUD_ICMP:
                        src_add_name: DC1_CLOUD_NET
                        dst_add: 0.0.0.0/0
                        protocol: icmp
                        nat_pool: INTERPOD
    destination_nat:
        pools:
            DNAT_SVC:
                address: 10.190.0.255/32
            DANT_PORT:
                address: 10.190.0.254
                port: 8443
        rule_sets:
            DNAT_SVC:
                from_zone:
                    - INTERPOD
                    - DMZ
                rules:
                    HTTPS_SERVER:
                        src_add: 0.0.0.0/0
                        dst_add: 1.1.10.31
                        protocol: tcp
                        port: 443
                        nat_pool: DANT_PORT
                    SMTP:
                        src_add: 0.0.0.0/0
                        dst_add: 1.1.10.30
                        protocol: tcp
                        dest_port_range:
                            - 25
                            - 100
                        nat_pool: DNAT_SVC

ip_sla:
    rpm:
        TEST:
            target_dst: 8.8.8.8
            src: 10.192.100.184
            next_hop: 10.192.100.1
            probe_count: 5
            probe_interval: 1
            probe_type: udp-ping
            test_interval: 6
            history_size: 256
            success_loss: 3
            total_loss: 4
    ip_monitoring:
        rpm:


l3_protocols:
    bgp:
        global_as: 65500
        groups:
            INTERPOD_EDGE_PEERINGS:
                peering_type: external
                multipath: True
                enforce_first_as: True
                local_peer: 10.192.99.21
                family:
                    inet:
                        - name: unicast
                        - name: multicast
                          options:
                              as_loops: 2
                remote_peer:
                    - neighbour: 10.192.99.22
                      hold_time: 10
                      peer_as: 65501
                      description: SPINE0 PEERING
                    - neighbour: 10.192.99.23
                      hold_time: 20
                      description: SPINE1 PEERING
                      peer_as: 65502
            DCI_PEERINGS:
                peering_type: external
                multipath: True
                enforce_first_as: True
                bfd_timers:
                    min_interval: 1000
                    multiplier: 3
                family:
                    inet:
                        - name: unicast
                remote_peer:
                    - neighbour: 10.192.99.129
                      local_peer: 10.192.99.128
                      peer_as: 65501
                      description: DCI PRIMARY PEERING
                      export_profile: DCI-EXPORT-PRIMARY
                      import_profile: DCI-IMPORT-PRIMARY
                      auth_key: "{{ lookup('hashi_vault','secret=networking/data/routing_protocols/bgp:dci_one') }}"
                    - neighbour: 10.192.99.131
                      local_peer: 10.192.99.130
                      peer_as: 65502
                      description: DCI SECONDARY PEERING
                      export_profile: DCI-EXPORT-SECONDARY
                      import_profile: DCI-IMPORT-SECONDARY
                      auth_key: "{{ lookup('hashi_vault','secret=networking/data/routing_protocols/bgp:dci_two') }}"


filters_v4:
  SELECTIVE_PACKET_FORWARDING:
    PACKET_FORWARDING:
      from:
        prefix_list:
          - INTERNAL
      then:
        count: SPF
        terminate_action: packet-mode
    ELSE:
      then:
        terminate_action: accept

route_maps:
    DCI-EXPORT-PRIMARY:
        EXPORT-DC1:
            from:
                prefix_list:
                    - DCI-1
            then:
                metric: 10
                local_preference: 200
                terminate_action: accept
        DEFAULT_DENY:
            then:
                terminate_action: reject
    DCI-EXPORT-SECONDARY:
        EXPORT-DC1:
            from:
                prefix_list:
                    - DCI-1
            then:
                metric: 10
                local_preference: 200
                terminate_action: accept
        DEFAULT_DENY:
            then:
                terminate_action: reject

    DCI-IMPORT-PRIMARY:
        IMPORT-DC2:
            from:
                prefix_list:
                    - DCI-2
            then:
                metric: 10
                local_preference: 200
                terminate_action: accept
        DEFAULT_DENY:
            then:
                terminate_action: reject
    DCI-IMPORT-SECONDARY:
        IMPORT-DC2:
            from:
                prefix_list:
                    - DCI-2
            then:
                metric: 10
                local_preference: 200
                terminate_action: accept
        DEFAULT_DENY:
            then:
                terminate_action: reject
