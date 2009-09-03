package YaPI::NETWORK;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;
use Switch;

# ------------------- imported modules
YaST::YCP::Import ("LanItems");
YaST::YCP::Import ("NetworkInterfaces");
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
 NetworkInterfaces->Read();

 my %interfaces = ();
 foreach my $devnum (keys %{LanItems->Items}){
  my $devname= %{LanItems->Items}->{$devnum}->{'hwinfo'}->{'dev_name'};
  my $name = %{LanItems->Items}->{$devnum}->{'ifcfg'};
  if ($name ne ""){
    my %configuration = ();
    NetworkInterfaces->Select($name);
    my %config = %{NetworkInterfaces->Current};
    my $bootproto = %config->{'BOOTPROTO'};
    switch($bootproto){
      case "dhcp" {
        %configuration = ( 'bootproto' => 'dhcp' );
       }
      case "static" {
	%configuration = ( 'bootproto' => 'static' );
        %configuration->{'ipaddr'} = %config->{'IPADDR'} . "/" . %config->{'PREFIXLEN'}
       }
    }
    $interfaces{$name}=\%configuration;
  }
 }

  my %ret	= ('interfaces'=>\%interfaces,
		   'routes'=>{'default'=>{'via'=>Routing->GetGateway()}}, 
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
