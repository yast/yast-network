#
# spec file for package yast2-network
#
# Copyright (c) 2016 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-network
Version:        3.2.17
Release:        0
BuildArch:      noarch

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0
BuildRequires:  update-desktop-files
BuildRequires:  yast2-devtools >= 3.1.15
Requires:       yast2-proxy
#for install task
BuildRequires:  rubygem(yast-rake)

# yast2 v3.1.86: Added ServicesProposal library
BuildRequires:  yast2 >= 3.1.86
# Network: Adapt old enslaved interface config
Requires:       yast2 >= 3.1.206.2

# Product control need xml agent
BuildRequires:  yast2-xml
Requires:       yast2-xml

#netconfig (FaTE #303618)
Requires:       sysconfig >= 0.80.0
# Storage::IsDeviceOnNetwork
BuildRequires:  yast2-storage >= 2.21.11
Requires:       yast2-storage >= 2.21.11
# Packages::vnc_packages
Requires:       yast2-packager >= 3.1.47
# cfa for parsing hosts
BuildRequires:  rubygem(%rb_default_ruby_abi:cfa)
Requires:       rubygem(%rb_default_ruby_abi:cfa)
# lenses are needed to use cfa
BuildRequires:  augeas-lenses
Requires:       augeas-lenses
# BusID of all the cards with the same one (bsc#1007172)
Requires:       hwinfo         >= 21.35

# testsuite
BuildRequires:  rubygem(rspec)

PreReq:         /bin/rm

# carrier detection
Conflicts:      yast2-core < 2.10.6

Requires:       yast2-ruby-bindings >= 1.0.0

Obsoletes:      yast2-network-devel-doc

Summary:        YaST2 - Network Configuration

%description 
This package contains the YaST2 component for network configuration.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%install
rake install DESTDIR="%{buildroot}"

%files
%defattr(-,root,root)
%{yast_ybindir}/*
%{yast_yncludedir}/network
%{yast_clientdir}/*.rb
%dir %{yast_moduledir}/YaPI
%{yast_moduledir}/YaPI/NETWORK.pm
%{yast_moduledir}/*.rb
%{yast_desktopdir}/*.desktop
%{yast_scrconfdir}/*.scr
%{yast_agentdir}/ag_udev_persistent
%{yast_schemadir}/autoyast/rnc/networking.rnc
%{yast_schemadir}/autoyast/rnc/host.rnc
%{yast_libdir}/network
%dir %{yast_libdir}/cfa/
%{yast_libdir}/cfa/hosts.rb
%{yast_ydatadir}/network

%dir %{yast_docdir}
%doc %{yast_docdir}/CONTRIBUTING.md
%doc %{yast_docdir}/COPYING
%doc %{yast_docdir}/README.md

%changelog
