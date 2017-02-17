#
# Cookbook Name:: bts-netbackup
# Recipe:: default
#
# Copyright (c) 2017 Toyota - Cloud Automation

require 'mixlib/shellout'

# Is this running in TCD or TCX?
cmd = Mixlib::ShellOut.new("netstat -r |grep default|awk '{print $2}'|cut -d'.' -f2")
cmd.run_command

# This is the data center found using the previous command
net = cmd.stdout

# Override for now - please remove
net = '60' 

case net 
when "60"
  site = "tcd"
when "61"
  site = "tcx"
else
  return
end

# Get IP addresses
cmd = Mixlib::ShellOut.new("/usr/sbin/ip addr show  | grep -Po 'inet \\K[\\d.]+' | grep -i 172 | grep -v 172.28")
cmd.run_command
iplist = cmd.stdout.split("\n")

# Create temporary directory
directory "/tmp/netbackup" do
  action :create
end

# Download Netbackup
remote_file "/tmp/netbackup/netbackup-agent-latest.tar.gz" do
  source "#{node['bts_netbackup_agent']['repo']}/software/linux/netbackup/linux/netbackup-agent-latest.tar.gz"
end

bash "install_netbackup_package" do
  code <<-EOH
    cd /tmp/netbackup/
    tar zvf netbackup-agent-latest.tar.gz
    echo y | ./install
  EOH
end

# Download list of Netbackup servers
remote_file "/tmp/netbackup/#{site}.netbackup_servers" do
  source "#{node['bts_netbackup_agent']['repo']}/#{site}.netbackup_servers"
end

# Configure Netbackup
iplist.each do |ip|
  bash "configure_netbackup" do
    code <<-EOH
      cd /tmp/netbackup/
      "egrep -w #{ip} $site.netbackup_servers | awk '{print "SERVER = "$2} {print "SERVER = "$3}' > bp.conf"
      echo "CONNECT_OPTIONS = localhost 1 0 2" >> bp.conf
      netbackup_master=`awk '{ print $3 }' bp.conf | head -1`
      netbackup_client=`hostname`-bip
      echo "SERVER=$netbackup_master" >> /tmp/NBInstallAnswer.conf
      echo "CLIENT_NAME=$netbackup_client" >> /tmp/NBInstallAnswer.conf
      echo "SERVICES=no" >> /tmp/NBInstallAnswer.conf
    EOH
  end
end

# Install additional packages
%w{ VRTSnbpck.rpm VRTSpbx.rpm VRTSnbclt.rpm VRTSnbjre.rpm VRTSnbjava.rpm VRTSpddea.rpm VRTSnbcfg.rpm }.each do |pkg|
  package pkg do
    # investigate ending wildcard
    source "/tmp/netbackup/NBClients/anb/Clients/usr/openv/netbackup/client/Linux/RedHat/#{pkg}"
    action :install
  end
end

# Copy Netbackup configuration
execute "cp /tmp/netbackup/bp.conf /usr/openv/netbackup/bp.conf" do
  action :run
end

# Delete temporary directory
directory "/tmp/netbackup" do
  action :delete
end
