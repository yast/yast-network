#! /usr/bin/perl -w
#
# Copyright 2004, Novell, Inc.  All rights reserved.
# File:	modules/SuSEFirewallInterfaces.pm
# Authors:	Lukas Ocilka <locilka@suse.cz>
#		Martin Vidner <mvidner@suse.cz>
# Summary:	Access to the yast2-firewall module
#

package SuSEFirewallInterfaces;

use strict;
use YaST::YCP qw(Boolean sformat y2milestone);

YaST::YCP::Import ("SuSEFirewall");

our %TYPEINFO;

BEGIN { $TYPEINFO{Read} = ["function", "boolean" ] };
sub Read {
    y2milestone("Reading the configuration.");
    return SuSEFirewall->Read();
}

BEGIN { $TYPEINFO{Write} = ["function", "boolean" ] };
sub Write {
    y2milestone("Writing the configuration.");
    return SuSEFirewall->Write();
}

# hack for -> is firewall running and is this interface external?
BEGIN { $TYPEINFO{IsProtectedByFirewall} = ["function", "boolean", "string"]; }
sub IsProtectedByFirewall {
    my $class = shift;
    my $interface = shift;

    my $firewall_is_running = SuSEFirewall->start;
    my $is_ext_interfaces   = SuSEFirewall->IsExtInterface($interface);

    if ($firewall_is_running && $is_ext_interfaces) {
	return 1;
    }
    return 0;
}

BEGIN { $TYPEINFO{ProtectByFirewall} = ["function",
    "boolean",
    "string", "boolean"];
}
sub ProtectByFirewall {
    my $class = shift;
    my $interface = shift;
    my $protect = shift;

    SuSEFirewall->SetModified();

    # if $protect is true  -> add interface into external, set to start firewall
    # if $protect is flase -> remove interface from external
    #			   -> disable to start firewall if no other devices are in INT, DMZ and EXT

    # reading settings
    my $firewall_settings = SuSEFirewall->settings;
    if ($protect) {
	# add into external, enable firewall
	$firewall_settings->{'FW_DEV_EXT'} .= ($firewall_settings->{'FW_DEV_EXT'} ? " ":"").$interface;
	y2milestone("Interface '".$interface."' was added into external firewall devices.");

	SuSEFirewall->enable_firewall(1);
	SuSEFirewall->start(1);
	y2milestone("Firewall is enabled.");
    } else {
	# remove from external, disable firewall if needed
	my @dev_ext = split(/ /, $firewall_settings->{'FW_DEV_EXT'});
	@dev_ext = grep { $_ !~ /$interface/ } @dev_ext;
	$firewall_settings->{'FW_DEV_EXT'} = join(" ", @dev_ext);
	y2milestone("Interface '".$interface."' was removed from external firewall devices.");

	$firewall_settings->{'FW_DEV_EXT'} = "" if (not defined $firewall_settings->{'FW_DEV_EXT'});
	$firewall_settings->{'FW_DEV_INT'} = "" if (not defined $firewall_settings->{'FW_DEV_INT'});
	$firewall_settings->{'FW_DEV_DMZ'} = "" if (not defined $firewall_settings->{'FW_DEV_DMZ'});

	if ($firewall_settings->{'FW_DEV_EXT'}.
	    $firewall_settings->{'FW_DEV_INT'}.
	    $firewall_settings->{'FW_DEV_DMZ'} eq ""
	) {
	    SuSEFirewall->enable_firewall(0);
	    SuSEFirewall->start(0);
	    y2milestone("Firewall is disabled.");
	} else {
	    y2milestone("Firewall is still running.");
	}
    }
    # setting settings back into firewall
    SuSEFirewall->settings($firewall_settings);

    return 1;
}

1;
