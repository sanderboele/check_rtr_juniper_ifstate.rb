This is a ruby nagios script for checking interface status on a JUNOS device.

This script first filters out all non-phyiscal interfaces, then checks the description suffix on the interface:

<ul>
	<li>FREE - interface should be admin down, warning is generated if this is not the case</li>
	<li>CUST - interface should be up and running, if not, a warning is generated</li>
	<li>ACCESS - we don't care about this interface</li>
	<li>CORE - we care very much about this interface, it should be up and running or a critical is raised</li>
</ul>

It has been tested on qfabric, MX960, EX4200, EX4550.