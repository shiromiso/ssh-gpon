# Nokia G-010S-A GPON Diagnostic Script

Script to connect to a Nokia G-010S-A GPON module through a UniFi gateway.

```
This script will:
  SSH to UniFi
  Set up a temp IP address on GPON interface
  SSH to GPON
  Remove temp IP when done

To query link status:
  onu ploamsg

Read "curr_state" value.

Normal status:
  5 - Link operational and registered
Other status:
  1 - No usable optical signal; check fiber
  2 - Optical signal detected; awaiting activation
  3 - ONU identification/authentication in progress
  4 - Timing and distance calibration in progress
  6 - Temporary loss of synchronization/recovery
  7 - ONU disabled by the OLT; transmitter stopped

For more info, refer to this excellent repo:
  https://github.com/hwti/G-010S-A
```
