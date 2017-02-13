#
# Cookbook Name:: bts_netbackup_agent
# Recipe:: default
#
# Copyright (c) 2017 The Authors, All Rights Reserved.

require 'mixlib/shellout'

# Is this running in TCD or TCX?
net = node['default_gateway'].split(".")

case net[1]
when "60"
  site = "tcd"
when "61"
  site = "tcx"
else
  return
end

iplist = Mixlib::ShellOut.new("/usr/sbin/ip addr show  | grep -Po 'inet \K[\d.]+' | grep -i 172 | grep -v 172.28")

if iplist.nil?
  Chef::Log.fatal("Netbackup backup interface is not configured.  Please plumb the interface and rerun this cookbook.  Exiting ...")
else
  Chef::Log.info("Proceeding with Netbackup Client installation ...")
end

directory "/tmp/netbackup-$$" do
  action :create
end

remote_file "/tmp/netbackup-$$/netbackup-agent-latest.tar.gz"
  source "#{node['bts_netbackup_agent']['repo']/software/linux/netbackup/linux/netbackup-agent-latest.tar.gz"
end

bash "install_netbackup_package" do
  code <<-EOH
    cd /tmp/netbackup/-$$
    tar zvf netbackup-agent-latest.tar.gz
    echo y | ./install
  EOH
end

remote_file "/tmp/netbackup-$$/#{site}.netbackup_servers"
  source "#{node['bts_netbackup_agent']['repo']}/#{site}.netbackup_servers"
end

iplist.stdout.each do |ip|
  tmp =  ip.stdout.split(".")
  second_octet = tmp[1]
  third_octet = tmp[2]
  ip_to_check = 172.second_octet.third_octet
end

bash "configure_netbackup" do
  code <<-EOH
    cd /tmp/netbackup/-$$
    "egrep -w #{ip_to_check} $site.netbackup_servers | awk '{print "SERVER = "$2} {print "SERVER = "$3}' > bp.conf"
    echo "CONNECT_OPTIONS = localhost 1 0 2" >> bp.conf
    netbackup_master=`awk '{ print $3 }' bp.conf | head -1`
    netbackup_client=`hostname`-bip
    echo "SERVER=$netbackup_master" >> /tmp/NBInstallAnswer.conf
    echo "CLIENT_NAME=$netbackup_client" >> /tmp/NBInstallAnswer.conf
    echo "SERVICES=no" >> /tmp/NBInstallAnswer.conf
  EOH
end

%w{ VRTSnbpck.rpm VRTSpbx.rpm VRTSnbclt.rpm VRTSnbjre.rpm VRTSnbjava.rpm VRTSpddea.rpm VRTSnbcfg.rpm }.each do |pkg|
  package pkg do
    # investigate ending wildcard
    source "/tmp/netbackup/-$$/NBClients/anb/Clients/usr/openv/netbackup/client/Linux/RedHat/#{pkg}"
    action :install
  end
end

execute "cp /tmp/netbackup/-$$/bp.conf /usr/openv/netbackup/bp.conf" do
  action :run
end

directory "/tmp/netbackup-$$" do
  action :delete
end


