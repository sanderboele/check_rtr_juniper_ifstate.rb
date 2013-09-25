#!/usr/bin/env ruby
require 'rubygems'
require 'snmp'
require 'timeout'

include SNMP

# Nagios script written by Sander Boele <sander.boele@surfsara.nl> 20-08-2013 in an
# attempt to reduce >5 min execution time on qfabric with our old perl script
#
# This script checks interfaces that have a description ending in CORE and CUST
# If a CORE interface is down, an alarm is generated. If a CUST interface is down,
# a warning is generated. If a CORE interface is admin down, a warning is generated.
#
# possible values for ifState:
# 1 : up
# 2 : down
# 3 : testing
# 4 : unknown
# 5 : dormant
# 6 : notPresent
# 7 : lowerLayerDown

linkStates = [ "", "up", "down", "testing", "unknown", "dormant", "notPresent", "lowerLayerDown"]

start = Time.now

if (ARGV.count < 2)
  puts "Please run this script with host and SNMP community argument and optional --debug argument"
  puts "i.e. #{$0} my_switch my_community [--debug]"
  exit(1)
end

class Interface
  attr_accessor :ifAlias, :ifName, :ifOperStatus, :ifAdminStatus
  def initialize(ifAlias, name, operStatus, adminStatus)
    @ifAlias = ifAlias
    @ifName = name
    @ifOperStatus = operStatus
    @ifAdminStatus = adminStatus
    @alarm = 0
    @warning = 0
    if defined?(@@numInterfaces)
      @@numInterfaces += 1
    else
      @@numInterfaces = 1
      @@numAlarms = 0
      @@numWarnings = 0
      @@messages = Array.new
      @@numAdminUp = 0
      @@numOperUp = 0
    end

    if (adminStatus == 1)
      @@numAdminUp +=1
    end

    if (operStatus == 1)
      @@numOperUp +=1
    end

    #if an interface is admin up/down with CORE suffix:
    if (ifAlias =~ /CORE$/ and adminStatus == 1 and operStatus != 1)
      @alarm=1
      @@numAlarms+=1
      @@messages << "CORE interface #{name} #{ifAlias} is down"
    #if an interface has CUST suffix and is down:
    elsif (ifAlias =~ /CUST$/ and operStatus == 2)
      @warning=1
      @@numWarnings+=1
      @@messages << "CUST interface #{name} #{ifAlias} is down"
    #if an interface does not have a CORE/ACCESS/CUST/FREE suffix:
    elsif (ifAlias !~ /(CORE|ACCESS|CUST|FREE)$/)
      @warning=1
      @@numWarnings+=1
      @@messages << "interface #{name} #{ifAlias} has a bad suffix in description."
    end
    #if an interface with a CORE suffix is admin down:
    if (ifAlias =~ /CORE$/ and adminStatus ==2)
      @warning=1
      @@numWarnings+=1
      @@messages << "CORE interface #{name} #{ifAlias} is admin down"
    end
    #an interface with a FREE suffix should not be up
    if (ifAlias =~ /FREE$/ and operStatus == 1)
      @warning=1
      @@numWarnings+=1
      @@messages << "FREE interface #{name} #{ifAlias} is up?!"
    end
    #an interface with a FREE suffix should be admin down
    if (ifAlias =~ /FREE$/ and adminStatus == 1 and operStatus == 2)
      @warning=1
      @@numWarnings+=1
      @@messages << "FREE interface #{name} #{ifAlias} should be admin down"
    end
  end
  def self.count
    @@numInterfaces
  end
  def self.printStatus
    @@messages.each { |message| puts message }
  end
  def self.countAdminUp
    @@numAdminUp
  end
  def self.countOperUp
    @@numOperUp
  end
  def self.countAlarms
    @@numAlarms
  end
  def self.countWarnings
    @@numWarnings
  end
end

lookup_values = ["ifAlias", "ifName", "ifOperStatus", "ifAdminStatus"]
begin
  Timeout.timeout(90) do
    SNMP::Manager.open(:Host => ARGV[0], :Community => ARGV[1]) do |manager|
      manager.walk(lookup_values) do |ifAlias, ifName, ifOperStatus, ifAdminStatus|
        #only create interface objects for main physical interfaces, not subinterfaces
        if (ifName.value =~ /^(fte-|ae|xe-|ge-|qnode\d:xe|NW-NG-0:ae)/ and ifName.value !~ /\.\d+$/)
          Interface.new(ifAlias.value, ifName.value, ifOperStatus.value, ifAdminStatus.value)
          #if the third argument is --debug, print out all interface data
          if (ARGV[2] == "--debug")
            puts "ifName: #{ifName.value} ifAlias: #{ifAlias.value} ifOperStatus: #{linkStates[ifOperStatus.value.to_i]} ifAdminStatus: #{linkStates[ifAdminStatus.value.to_i]}"
          end
        end
      end
    end
  end
rescue Timeout::Error
  puts "SNMP execution is taking longer than 90s"
  exit(1) #immediately exit
rescue SNMP::RequestTimeout
  puts "Host #{ARGV[0]} is not responding to SNMP"
  exit(1) #immediately exit
rescue
  puts "Host #{ARGV[0]} is not resolving or not responding to SNMP"
  exit(1)
end

if (Interface.countAlarms > 0)
  puts "Critical!"
  exitCode = 2 #Nagios will pick this up as a red alert
elsif
  (Interface.countWarnings > 0)
  puts "Warning!"
  exitCode = 1 #Nagios will pick this up as a yellow alert
else
  puts "Everything OK"
  exitCode = 0 #Green in Nagios
end

Interface.printStatus
puts "Total interfaces: #{Interface.count}, #admin Up: #{Interface.countAdminUp}, #oper Up: #{Interface.countOperUp}"
puts "Interface check completed in #{(Time.now - start).round.to_s} second(s)."
exit(exitCode)
