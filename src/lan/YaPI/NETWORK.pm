#--
## Copyright (c) 2009 Novell, Inc.
##
## All Rights Reserved.
##
## This program is free software; you can redistribute it and/or modify it
## under the terms of version 2 of the GNU General Public License
## as published by the Free Software Foundation.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, contact Novell, Inc.
##
## To contact Novell about this file by physical or electronic mail,
## you may find current contact information at www.novell.com
##++
## = Network interface model
## Provides set and gets resources from YaPI network module.
## Main goal is handle YaPI specific calls and data formats. Provides cleaned
## and well defined data.


package YaPI::NETWORK;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;

# ------------------- imported modules
YaST::YCP::Import ("LanItems");
YaST::YCP::Import ("Hostname");
YaST::YCP::Import ("Host");
YaST::YCP::Import ("DNS");
YaST::YCP::Import ("Routing");
# -------------------------------------

our $VERSION            = '1.0.0';
our @CAPABILITIES       = ('SLES11');
our %TYPEINFO;

# TODO: parameter map<string, boolean> what_I_Need
BEGIN{$TYPEINFO{Read} = ["function",
                         [ "map", "string", "any"]];
}
sub Read {
    my $self	= shift;

    DNS->Read();
    Routing->Read();
    LanItems->Read();

    my %interfaces = ();
    foreach my $devnum (keys %{LanItems->Items}){
        LanItems->current($devnum);
        if (LanItems->IsItemConfigured()){
            LanItems->SetItem();
            my %configuration = (
                'startmode' => LanItems->startmode ne ''? LanItems->startmode: 'manual',
                'bootproto' => LanItems->bootproto,
            );
            if (LanItems->bootproto eq "static"){
                $configuration{'ipaddr'} = LanItems->ipaddr;
                if (LanItems->prefix ne "") {
                     $configuration{'ipaddr'} .= "/" . LanItems->prefix
                }
            }

            $configuration{'mtu'} = LanItems->mtu;
            y2milestone("************* Interface type ", Dumper(LanItems->type));
            if(LanItems->type eq "vlan") {
                if (LanItems->vlan_id){
                    $configuration{'vlan_id'} = LanItems->vlan_id;
                }
                
                if (LanItems->vlan_etherdevice){
                    $configuration{'vlan_etherdevice'} = LanItems->vlan_etherdevice;
                }
            }

	        if(LanItems->type eq "br" && LanItems->bridge_ports) {
	            y2milestone("*** BRIDGE DETECTED GET BRIDGE_PORTS ********************");
		        $configuration{'bridge_ports'} = LanItems->bridge_ports; 
            }


            if(LanItems->type eq "bond") {
                if(@{LanItems->bond_slaves}) {
                    $configuration{'bond_slaves'} = LanItems->bond_slaves;
                }
                
                if(@{LanItems->bond_slaves}) {
                    $configuration{'bond_slaves'} = LanItems->bond_slaves;
                }
        
        	    if(LanItems->bond_option) {
            		$configuration{'bond_option'} = LanItems->bond_option; 
                }
            }

	    if(LanItems->getCurrentItem()->{'hwinfo'}->{'type'} eq "eth") {
		$configuration{'vendor'} = LanItems->getCurrentItem()->{"hwinfo"}->{"name"};
	    }

            $interfaces{LanItems->interfacename}=\%configuration;

        } elsif (LanItems->getCurrentItem()->{'hwinfo'}->{'type'} eq "eth") {
            my $device = LanItems->getCurrentItem()->{"hwinfo"}->{"dev_name"};
	    $interfaces{$device}= {};

	    if(LanItems->getCurrentItem()->{'hwinfo'}->{'type'} eq "eth") {
		$interfaces{$device}= {'vendor' => LanItems->getCurrentItem()->{"hwinfo"}->{"name"}};
	    } 

	    $interfaces{$device}
	}
    }

    #FIXME: validate for nil values (dns espacially)
    my %ret	= (
        'interfaces' => \%interfaces,
        'routes' => {
            'default' => {
                'via' => Routing->GetGateway()
            }
        }, 
        'dns' => {
            'nameservers' => \@{DNS->nameservers},
            'searches'    => \@{DNS->searchlist}
        },
        'hostname' => {
            'name'          => Hostname->CurrentHostname,
            'domain'        => Hostname->CurrentDomain,
            'dhcp_hostname' => DNS->dhcp_hostname
        }
        );
    return \%ret;
}

sub writeRoute {
    my $args  = shift;
    my %ret = ('exit'=>0, 'error'=>'');

    my $gw="";
    my $dest="";
    my @route = ();
    if (defined ($args->{'route'}->{'default'}->{'via'})){
        $gw = $args->{'route'}->{'default'}->{'via'};
        if ($gw ne ""){
            YaST::YCP::Import ("IP");
            unless (IP->Check4($gw)) {
                $ret{'exit'} = -1;
                $ret{'error'} = IP->Valid4();
                return \%ret;	
            };
            $dest = "default";
            @route = ( {"destination" => $dest,
                        "gateway" => $gw,
                        "netmask" => "-",
                        "device" => "-"
                       });
        }
    }
    Routing->Read();
    y2milestone("YaPI->Write before change Routes:", Dumper(Routing->Routes));
    Routing->Routes( \@route );
    y2milestone("YaPI->Write after change Routes:", Dumper(Routing->Routes));
    Routing->Write();
    return \%ret;	
}

sub writeHostname {
    my $args  = shift;
    my $ret = {'exit'=>0, 'error'=>''};
    y2milestone("hostname", Dumper(\$args->{'hostname'}));
    DNS->Read();
    DNS->hostname($args->{'hostname'}->{'name'});
    DNS->domain($args->{'hostname'}->{'domain'});
    DNS->dhcp_hostname($args->{'hostname'}->{'dhcp_hostname'}) if (defined $args->{'hostname'}->{'dhcp_hostname'});
    DNS->modified(1);
    DNS->Write();
    Host->Read();
    Host->EnsureHostnameResolvable();
    Host->Write();
    return $ret;
}

sub writeDNS {
    my $args  = shift;
    my $ret = {'exit'=>0, 'error'=>''};
    y2milestone("dns", Dumper(\$args->{'dns'}));
    DNS->Read();
    DNS->nameservers($args->{'dns'}->{'nameservers'});
    DNS->searchlist($args->{'dns'}->{'searches'});
    DNS->modified(1);
    DNS->Write();
    return $ret;
}

sub writeInterfaces {
    my $args  = shift;
    my $ret = {'exit'=>0, 'error'=>''};

    y2milestone("interface", Dumper(\$args->{'interface'}));

    while (my ($dev, $ifc) = each %{$args->{'interface'}}) {
        YaST::YCP::Import ("NetworkInterfaces");
        NetworkInterfaces->Read();
        NetworkInterfaces->Add() unless NetworkInterfaces->Edit($dev);
        NetworkInterfaces->Name($dev);

	if (defined $ifc->{'delete'} && $ifc->{'delete'} eq "true") {
	   y2milestone("Delete virtual interface", Dumper(\$dev));

	   NetworkInterfaces->Delete($dev);
	   NetworkInterfaces->Commit();
	   NetworkInterfaces->Write("");
	   YaST::YCP::Import ("Service");
	   Service->Restart("network");

        } else {
		my %config=("STARTMODE" => defined $ifc->{'startmode'}? $ifc->{'startmode'}: 'auto',
		            "BOOTPROTO" => defined $ifc->{'bootproto'}? $ifc->{'bootproto'}: 'static',
		    );
		if (defined $ifc->{'ipaddr'}) {
		    my $prefix = "32";
		    YaST::YCP::Import ("Netmask");
		    my @ip_row = split(/\//, $ifc->{'ipaddr'});
		    $prefix = $ip_row[$#ip_row];
		    if (Netmask->Check4($prefix) && $prefix =~ /\./){
		        y2milestone("Valid netmask: ", $prefix, " will change to prefixlen");
		        $prefix = Netmask->ToBits($prefix);
		    }
		    $config{"IPADDR"} = $ip_row[0]."/".$prefix;
		}
		if (defined $ifc->{'mtu'}) {
		    $config{"MTU"} = $ifc->{'mtu'};
		}
		if (defined $ifc->{'vlan_id'}) {
		    $config{"VLAN_ID"} = $ifc->{'vlan_id'};
		}
		if (defined $ifc->{'vlan_etherdevice'}) {
		    $config{"ETHERDEVICE"} = $ifc->{'vlan_etherdevice'};
		}

		if (defined $ifc->{'bridge'}) {
		    y2milestone("*** BRIDGE DETECTED ***");
		    y2milestone(Dumper($ifc->{'bridge_ports'}));
		    $config{"BRIDGE"} = "yes";
		    $config{"BRIDGE_PORTS"} = $ifc->{'bridge_ports'};
		}
	  
		if (defined $ifc->{'bond'}) {
		    y2milestone("*** bonding settings *******************************");
		    $config{"BONDING_MASTER_MASTER"} = "yes";
		    $config{"BONDING_MODULE_OPTS"} = $ifc->{'bond_option'};
		    #$config{"BONDING_SLAVE"} = $ifc->{'bond_option'};

		    my @slaves = split(/ /,$ifc->{'bond_slaves'});	    
		    
		    for my $i (0 .. length(@slaves)) {
                y2milestone("BONDING_SLAVE$i", @slaves[$i]); 
                $config{"BONDING_SLAVE$i"} = @slaves[$i];
            }
		}


		NetworkInterfaces->Current(\%config);
		NetworkInterfaces->Commit();
		NetworkInterfaces->Write("");
		YaST::YCP::Import ("Service");
		Service->Restart("network");
	}
    }
    return $ret;
}



BEGIN{$TYPEINFO{Write} = ["function",
                          ["map","string","any"],["map","string","any"]];
}

sub Write {
    my $self  = shift;
    my $args  = shift;
    y2milestone("YaPI->Write with settings:", Dumper(\$args));

    # SAVE DEFAULT ROUTE
    if (exists($args->{'route'})){
        my $route_ret = writeRoute($args);
        return $route_ret if ($route_ret->{'exit'} != 0);
    }
    # SAVE HOSTNAME
    if (exists($args->{'hostname'})){
        my $hn_ret = writeHostname($args);
        return $hn_ret if ($hn_ret->{'exit'} != 0);
    }
    # SAVE DNS Settings
    if (exists($args->{'dns'})){
        my $dns_ret = writeDNS($args);
        return $dns_ret if ($dns_ret->{'exit'} != 0);
    }
    # SAVE interfaces Settings
    if (exists($args->{'interface'})){
        my $ifc_ret = writeInterfaces($args);
        return $ifc_ret if ($ifc_ret->{'exit'} != 0);
    }

    # return value for exit is type integer, but it'll be converted into string (in yast-perl-bindings)
    # that means in rest-api it'll be {'exit'=>'0', 'error'=>''}
    return {'exit'=>0, 'error'=>''};
}


1;
