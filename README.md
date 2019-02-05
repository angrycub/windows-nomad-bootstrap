# windows-nomad-bootstrap

WIP Project to collect all of the depencencies to set up Nomad on a Windows Box using powershell + helpers

When running in a VM on XenServer, you will need to enable nested virtualization in order to install Hyper-V.  To do that, go to the console of the XenServer and run:

```
xe vm-param-set platform:exp-nested-hvm=true uuid=«UUID of the Windows VM»
```
