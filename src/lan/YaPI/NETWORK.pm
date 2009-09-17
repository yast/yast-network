package YaPI::NETWORK;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;
use Switch;

# ------------------- imported modules
YaST::YCP::Import ("LanItems");
YaST::YCP::Import ("Hostname");
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

# Hostname->Read();
 DNS->Read();
 Routing->Read();
 LanItems->Read();

 my %interfaces = ();
 foreach my $devnum (keys %{LanItems->Items}){
  LanItems->current($devnum);
  if (LanItems->IsItemConfigured()){
    my %configuration = ();
    LanItems->SetItem();
    if (LanItems->isCurrentDHCP()){
	%configuration = ( 'bootproto' => LanItems->bootproto );
    } elsif (LanItems->bootproto eq "static"){
	  %configuration = ( 'bootproto' => 'static' );
	  %configuration->{'ipaddr'} = LanItems->ipaddr . "/" . LanItems->prefix;
	}
    $interfaces{LanItems->interfacename}=\%configuration;
  } elsif (LanItems->getCurrentItem()->{'hwinfo'}->{'type'} eq "eth") {
	  $interfaces{%{LanItems->getCurrentItem()}->{"hwinfo"}->{"dev_name"}}= {};
	}
 }

  #FIXME: validate for nil values (dns espacially)
  my %ret	= ('interfaces'=>\%interfaces,
		   'routes'=>{'default'=>{'via'=>Routing->GetGateway()}}, 
                   'dns'=>{'nameservers'=>\@{DNS->nameservers}, 'searches'=>\@{DNS->searchlist}}, 
                   'hostname'=>{'name'=>Hostname->CurrentHostname, 'domain'=>Hostname->CurrentDomain}
		);
  return \%ret;
}

BEGIN{$TYPEINFO{Write} = ["function",
    "boolean",["map","string","any"]];
}
sub Write {
  my $self = shift;
  my $args = shift;
  y2milestone("YaPI->Write with settings:", Dumper(\$args));
  # SAVE DEFAULT ROUTE
  if (exists($args->{'route'})){
    my $gw="";
    my $dest="";
    my @route = ();
    if (defined ($args->{'route'}->{'default'}->{'via'})){
      $gw = $args->{'route'}->{'default'}->{'via'};
      if ($gw ne ""){
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
  }
  # SAVE HOSTNAME
  if (exists($args->{'hostname'})){
   y2milestone("hostname", Dumper(\$args->{'hostname'}));
   DNS->Read();
   DNS->hostname($args->{'hostname'}->{'name'});
   DNS->domain($args->{'hostname'}->{'domain'});
   DNS->modified(1);
   DNS->Write();
  }
  # SAVE DNS Settings
  if (exists($args->{'dns'})){
   y2milestone("dns", Dumper(\$args->{'dns'}));
   DNS->Read();
   DNS->nameservers($args->{'dns'}->{'nameservers'});
   DNS->searchlist($args->{'dns'}->{'searches'});
   DNS->modified(1);
   DNS->Write();
  }
  # SAVE DNS Settings
  if (exists($args->{'interface'})){
   y2milestone("interface", Dumper(\$args->{'interface'}));
   foreach my $dev (keys %{$args->{'interface'}}){
#           YaST::YCP::Import ("LanItems");
#           LanItems->Read();
#           foreach my $iface (keys %{LanItems->Items}){
#             LanItems->current($iface);
#             LanItems->DeleteItem();
#           }
#           LanItems->Write();
           YaST::YCP::Import ("NetworkInterfaces");
           NetworkInterfaces->Read();
           NetworkInterfaces->Add() if NetworkInterfaces->Edit($dev) ne 1;
           NetworkInterfaces->Name($dev);
           my %config=("STARTMODE" => "auto",
                        "BOOTPROTO" => $args->{'interface'}->{$dev}->{'bootproto'},
                        "IPADDR" => $args->{'interface'}->{$dev}->{'ipaddr'}
                        );
           NetworkInterfaces->Current(\%config);
           NetworkInterfaces->Commit();
           NetworkInterfaces->Write("");
           YaST::YCP::Import ("Service");
	   Service->Restart("network");
   }

  }

 return 1;
}

1;
