# IRE Mapping Script

## Map sources and the Crowdmap service

The mapper can download maps from one of three sources. Set the source with
`mconfig mapsource &lt;source&gt;`:

| Source | Command | What it uses |
| --- | --- | --- |
| Game | `mconfig mapsource game` | The map provided by the game. This is the default. |
| Published Crowdmap | `mconfig mapsource published` | The established, periodically published community map. |
| Crowdmap service | `mconfig mapsource service` | A live map assembled by the Crowdmap service from player reports. |

The published Crowdmap and the live service are different layers. The published
map is the conservative, static community release. The service map is updated
as reports arrive, so it will generally be more current, but it can also be
more fragile while a recent change has not yet been corroborated. Choose
`published` when you prefer the established release; choose `service` when you
want the most up-to-date shared map and are comfortable with that trade-off.

When `mapsource` is `service`, these additional settings appear in `mconfig`:

- `crowdmapserviceurl` is the service endpoint. Its default is
  `https://&lt;game&gt;.mudmaps.community`, which automatically uses the connected
  game's subdomain. Set an explicit URL only when using a different service.
- `crowdmapservicereports` is the number of independent reports required before
  another mapper's reported change is included in the map you download. The
  default is `2`; a higher value is more conservative, while `0` includes
  reports immediately. Your own reports are always included, so they remain in
  your downloaded map while awaiting independent confirmation.
- `crowdmapservicesend` controls whether your local mapping changes are sent to
  the service. It is off by default.

With sending enabled, successful persistent mapper operations—such as recording
room information, adding or removing exits, changing room and area details,
doors, labels, or other supported map data—are submitted as reports. Personal
or temporary mapper state, including private room marks, temporary travel
exits, and temporary labels, remains local. A successful local mapping
operation does not depend on the service: your local map is changed first. If
submitting the report fails, the mapper displays an error and the local edit
remains.

The service waits for a non-empty `gmcp.Char.Status.name` before checking or
downloading a service map, and uses that character name consistently for both
map requests and submitted reports. This avoids treating a Mudlet profile name
or a pre-login placeholder as a reporter.

The service only works well when people participate. If you use the service,
please enable `crowdmapservicesend`: your reports help keep the shared map
current and give other players the independent confirmation needed for their
report thresholds. You do not need to map deliberately to help: also enable
`gmcpmapupdates` and safe room information learned through normal gameplay can
be applied and contributed without a dedicated mapping session.

The service does not make a report universal by itself. Other reports and your
`crowdmapservicereports` threshold determine when it appears in other mappers'
service maps. Your own reports remain in your service map while awaiting
confirmation. Review the source selection and report threshold before relying
on newly reported map changes for navigation.

## GMCP map updates

`gmcpmapupdates` applies safe GMCP Room.Info fields to existing map rooms even
when mapping mode is disabled. It is disabled by default.

## Room marks

Room marks are private by default and stay only in your local map:

- `room mark home` creates a private mark at your current room.
- `room mark private home 1234` creates a private mark for room 1234.
- `room mark public bank 5678` creates a public mark that is reported when
  service sending is enabled.
- `room unmark home` removes a private mark; use `room unmark public bank` for
  a public one.

`room marks` lists both kinds. When downloading a new map, legacy marks that
are absent from, or differ from, the downloaded public marks are migrated to
the private set; matching marks remain public.

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
