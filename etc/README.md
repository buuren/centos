Current structure:

/usr/local/nagios/etc/
├── config
│   ├── cgi.cfg
│   ├── nagios.cfg
│   └── resource.cfg
├── hosts
│   ├── linux_hostgroups.cfg
│   ├── linux_hosts.cfg
│   ├── printer_hostgroups.cfg
│   ├── printer_hosts.cfg
│   ├── switch_hostgroup.cfg
│   ├── switch_hosts.cfg
│   ├── windows_hostgroups.cfg
│   └── windows_hosts.cfg
├── nrpe
│   └── nrpe.cfg
├── objects
│   ├── commands.cfg
│   ├── contacts.cfg
│   └── timeperiods.cfg
├── services
│   ├── localhost_services.cfg
│   ├── oracle6.ucm10g_services.cfg
│   ├── PCEE0469451.int.hansa.ee_services.cfg
│   ├── printer_services.cfg
│   └── switch_services.cfg
├── templates
│   ├── contact_template.cfg
│   ├── generic_host_template.cfg
│   ├── linux_host_templates.cfg
│   ├── printer_template.cfg
│   ├── service_templates.cfg
│   ├── switch_template.cfg
│   └── windows_host_templates.cfg
└── users
    └── htpasswd.users


My stucture for nagios configuration.

Add all files into nagios.cfg:

`for x in $(tree -if $PWD | grep '.cfg'); do echo "cfg_file=$x" >> /usr/local/nagios/etc/config/nagios.cfg; done`

After that:

Remove: nrpe.cfg, nagios.cfg, cgi.cfg, resource.cfg from /usr/local/nagios/etc/config/nagios.cfg
