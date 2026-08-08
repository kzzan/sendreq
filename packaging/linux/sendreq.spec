Name:           sendreq
Version:        %{sendreq_version}
Release:        1%{?dist}
Summary:        Desktop API workspace
License:        See repository
BuildArch:      x86_64
Source0:        %{name}-%{version}.tar.gz

%description
sendreq is a local-first desktop API workspace for REST, WebSocket, and gRPC.

%prep
%setup -q

%install
rm -rf %{buildroot}
cp -a usr %{buildroot}/

%files
/usr/bin/sendreq
/usr/lib/sendreq
/usr/share/applications/io.sendreq.desktop
/usr/share/icons/hicolor/256x256/apps/sendreq.png
