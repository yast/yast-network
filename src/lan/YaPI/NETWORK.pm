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
	  $configuration{'ipaddr'} = LanItems->ipaddr . "/" . LanItems->prefix;
	}
    $interfaces{LanItems->interfacename}=\%configuration;
  } elsif (LanItems->getCurrentItem()->{'hwinfo'}->{'type'} eq "eth") {
          my $device = LanItems->getCurrentItem()->{"hwinfo"}->{"dev_name"};
	  $interfaces{$device}= {};
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
   DNS->modified(1);
   DNS->Write();
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
   foreach my $dev (keys %{$args->{'interface'}}){
           YaST::YCP::Import ("NetworkInterfaces");
           NetworkInterfaces->Read();
           NetworkInterfaces->Add() unless NetworkInterfaces->Edit($dev);
           NetworkInterfaces->Name($dev);
	   my $ip = $args->{'interface'}->{$dev}->{'ipaddr'};
           my $prefix="32";
           YaST::YCP::Import ("Netmask");
           my @ip_row = split(/\//, $ip);
           $prefix = $ip_row[$#ip_row];
           if (Netmask->Check4($prefix) && $prefix =~ /\./){
                y2milestone("Valid netmask: ", $prefix, " will change to prefixlen");
                $prefix = Netmask->ToBits($prefix);
           }
		$ip = $ip_row[0]."/".$prefix;
           my %config=("STARTMODE" => "auto",
                        "BOOTPROTO" => $args->{'interface'}->{$dev}->{'bootproto'},
                        "IPADDR" => $ip
                        );
           NetworkInterfaces->Current(\%config);
           NetworkInterfaces->Commit();
           NetworkInterfaces->Write("");
           YaST::YCP::Import ("Service");
	   Service->Restart("network");
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
