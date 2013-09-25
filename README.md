This is a ruby nagios script for checking interface status on a JUNOS device.

This script first filters out all non-phyiscal interfaces, then checks the description suffix on the interface:

FREE - interface should be admin down, warning is generated if this is not the case
CUST - interface should be up and running, if not, a warning is generated
ACCESS - we don't care about this interface
CORE - we care very much about this interface, it should be up and running or a critical is raised

It has been tested on qfabric, MX960, EX4200, EX4550.