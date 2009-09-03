package YaPI::NETWORK;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;

# ------------------- imported modules
#YaST::YCP::Import ("Lan");
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

# FIXME: interfaces are a fake data, replace with real data from system
  my %ret	= ('interfaces'=>{
				'eth0'=>{'bootproto'=>'dhcp'}, 
				'eth1'=>{'bootproto'=>'static', 'ipaddr'=>'192.168.3.27/24'}},
		   'routes'=>{'default'=>{'via'=>Routing->GetGateway()}}, 
#                   'dns'=>{'dnsservers'=>join(' ', @{DNS->nameservers}), 'dnsdomains'=>join(' ', @{DNS->searchlist})}, 
                   'dns'=>{'dnsservers'=>\@{DNS->nameservers}, 'dnsdomains'=>\@{DNS->searchlist}}, 
                   'hostname'=>{'name'=>DNS->hostname, 'domain'=>DNS->domain}
		);

  return \%ret;
}

#BEGIN{$TYPEINFO{Get} = ["function",
#    [ "map", "string", "any"],
#    "string" ];
#}
#sub Get {
#
#  my $self	= shift;
#  my $name	= shift;
#
#  my $service	= {
#    "name"	=> $name,
#    "status"	=> Service->Status ($name)
#  };
#  return $service;
#}

BEGIN{$TYPEINFO{Execute} = ["function",
    [ "map", "string", "any"],
    "string", "string" ];
}
sub Execute {

  my $self	= shift;
  my $name	= shift;
  my $action	= shift;
  return Service->RunInitScriptOutput ($name, $action);
}
1;
