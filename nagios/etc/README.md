Current structure:

https://github.com/buuren/centos/blob/master/nagios/structure_tree.txt

My stucture for nagios configuration.

Add all files into nagios.cfg:

`for x in $(tree -if $PWD | grep '.cfg'); do echo "cfg_file=$x" >> /usr/local/nagios/etc/config/nagios.cfg; done`

After that:

Remove: nrpe.cfg, nagios.cfg, cgi.cfg, resource.cfg from /usr/local/nagios/etc/config/nagios.cfg
