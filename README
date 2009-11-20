IPSEC module for puppet
=======================

1. What this module does
------------------------

It enables IPSec on connections between the server and the clients of a service that is managed by puppet.

It allows to specify 'any' instead of a certain port, in this case connections over all ports between the clients and the server are encrypted.

It allows to define a set of ports to create only non IPSec connections on these Ports. The Puppet communication ports must be in that set else Puppet will not work anymore because it runs into an IPSec setup bootstrap problem: IPSec can not be enabled simultaneously on both nodes with Puppet.
Changes to this set of ports are propagated to the puppet clients with the next puppet run.

2. How to
---------

2.1 Installation

To be able to use this module all involved clients should be able to install the 'ipsec-tools' software package.
Just copy the module to your puppet modules directory on the puppetmaster.


2.2 Configuration

a.) FIRST of ALL: open the file (relative to your modules directory):

    ipsec/plugins/puppet/provider/ip_connection/ipsec.rb

At the beginning of the file adapt the set of ports that should be excluded from IPSec. Make sure that you add port(s) used by Puppet!
Puppet communication can not be protected by this IPSec module due to a bootstrap problem.
E.g:

    $nonIPSecPorts = Array[ "8140", "22" ]

b.) Assign the ipsec::base class to puppet clients that potentially will have connections secured by IPSec.

c.) Add the following to the manifest file of the service you want to apply IPSec to (syslog service is the example here):

    # exports these attributes to the puppetmaster database as a ip_connection type
    ipsec::ipconnection { "${ipaddress}_syslog":
        present     => "present",
        fqdn        => "$fqdn",
        sourceip    => "$ipaddress",
        destip      => "$logserver",
        port        => "666", # you could also use 'any': in this case connections on all ports but the ones specified in the set of exceptions are IPSec enabled!
        type        => "syslog",
    }

d.) This module uses the certificates used by puppet. Make sure the defaults in the following files point to the correct directories:

    ipsec/templates/racoon.conf.erb

e.) Test your configuration


3. Compatibility and Dependencies
---------------------------------

a.) This module was tested on SLES 10 and 11 distributions. If you want to use it on other systems, you may need copy and adapt the provider
    
    ipsec/plugins/puppet/provider/ip_connection/ipsec.rb
 
 At the moment there is a 'confine' in the provider allowing it only for SLES systems:

    confine :operatingsystem => ["SLES"] # this provider may be valid for other operating systems too, but was not tested on others than SLES

b.) To be able to use this module all involved clients should be able to install the 'ipsec-tools' software package.



License
=======

This program is free software; you can redistribute
it and/or modify it under the terms of the GNU
General Public License version 3 as published by
the Free Software Foundation.

