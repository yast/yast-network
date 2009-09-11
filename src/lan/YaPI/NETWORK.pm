package YaPI::NETWORK;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;
use Switch;

# ------------------- imported modules
YaST::YCP::Import ("LanItems");
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
    my %configuration = ();
    LanItems->SetItem();
    if (LanItems->isCurrentDHCP()){
	%configuration = ( 'bootproto' => LanItems->bootproto );
    } elsif (LanItems->bootproto eq "static"){
	  %configuration = ( 'bootproto' => 'static' );
	  %configuration->{'ipaddr'} = LanItems->ipaddr . "/" . LanItems->prefix;
	}
    $interfaces{LanItems->interfacename}=\%configuration;
  }
 }

  my %ret	= ('interfaces'=>\%interfaces,
		   'routes'=>{'default'=>{'via'=>Routing->GetGateway()}}, 
                   'dns'=>{'dnsservers'=>\@{DNS->nameservers}, 'dnsdomains'=>\@{DNS->searchlist}}, 
                   'hostname'=>{'name'=>DNS->hostname, 'domain'=>DNS->domain}
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

 return 1;
}

1;
