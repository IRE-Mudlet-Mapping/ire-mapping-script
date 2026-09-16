# IRE Mapping Script

## Crowdmap service

The mapper can optionally submit map edits to, and source maps from, a crowdmap
service. Both behaviors are disabled by default and can be configured
independently with `mconfig`:

- `crowdmapservicesend`: send local map mutations to the service.
- `crowdmapserviceurl`: base URL of the crowdmap service.
- `crowdmapservicesource`: download map versions and maps from the service.
- `crowdmapservicereports`: number of independent reports required in sourced maps.

## GMCP map updates

`gmcpmapupdates` applies safe GMCP Room.Info fields to existing map rooms even
when mapping mode is disabled. It is disabled by default.

This script allows [Mudlet's](http://www.mudlet.org) mapper to do autowalking on Achaea, Aetolia, Lusternia, Imperian, Starmourn or StickMUD. See the [download section](http://wiki.mudlet.org/w/IRE_mapping_script#Download) to get started!

It has many features such as:
- automatic repathing if you get offcourse
- locking of whole areas
- auto-swimming
- mapping
- scriptable exits

The script is originally written by Vadi and includes contributions from Kard, Keneanung, Patrick, Qwindor, Wyd and others! Would you like to add something? Submit a PR!

Are you a game admin and would like to add another game to the script? [See here](https://wiki.mudlet.org/w/Adding_your_mud_to_the_IRE_mapping_script).

Notable mappers:
- Qwindor (Achaea)
- you?
