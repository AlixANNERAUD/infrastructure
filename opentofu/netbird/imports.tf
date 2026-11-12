# Adopts what was set up in the dashboard: OpenTofu takes these objects over
# instead of creating new ones. Remove once the first apply has run.

import {
  to = netbird_account_settings.account
  id = "d9n1cp80rep000ci01o0"
}

import {
  to = netbird_group.anneraud
  id = "d9n59s00rep000c1f4c0"
}

import {
  to = netbird_group.infrastructure
  id = "d9nlf9o0rep000ff2d7g"
}

import {
  to = netbird_group.alix
  id = "d9ou13g0rep000fhv5b0"
}

import {
  to = netbird_group.client
  id = "d9phbeo0rep0008rokig"
}

import {
  to = netbird_group.paris
  id = "d9nhv4g0rep000fu8370"
}

import {
  to = netbird_network.host["bruxelles"]
  id = "da2ckmo0rep000ecqb9g"
}

import {
  to = netbird_network_resource.host["bruxelles"]
  id = "da2ckmo0rep000ecqb9g/da2ckv00rep000ecqbig"
}

import {
  to = netbird_network_router.host["bruxelles"]
  id = "da2ckmo0rep000ecqb9g/da2cl200rep000ecqbp0"
}

import {
  to = netbird_network.host["luxembourg"]
  id = "da9gplo0rep0008cmfp0"
}

import {
  to = netbird_network_resource.host["luxembourg"]
  id = "da9gplo0rep0008cmfp0/dartd1o0rep000c38ec0"
}

import {
  to = netbird_network_router.host["luxembourg"]
  id = "da9gplo0rep0008cmfp0/da9gpto0rep0008cmg8g"
}

import {
  to = netbird_network.host["paris"]
  id = "dan7t500rep000f29p70"
}

import {
  to = netbird_network_resource.host["paris"]
  id = "dan7t500rep000f29p70/dan7teg0rep000f29plg"
}

import {
  to = netbird_network_router.host["paris"]
  id = "dan7t500rep000f29p70/dan7th80rep000f29ptg"
}

import {
  to = netbird_policy.default
  id = "d9n1cp80rep000ci01pg"
}

import {
  to = netbird_policy.bruxelles_loopback
  id = "d9n2f7o0rep000ci1n70"
}

import {
  to = netbird_policy.host["bruxelles"]
  id = "da2ckv00rep000ecqbk0"
}

import {
  to = netbird_policy.host["luxembourg"]
  id = "dartd500rep000c38fb0"
}

import {
  to = netbird_policy.host["paris"]
  id = "dan7teg0rep000f29pn0"
}

import {
  to = netbird_policy.luxembourg_former
  id = "da9gprg0rep0008cmg3g"
}

import {
  to = netbird_policy.sfr
  id = "d9n1vf00rep000ci0vn0"
}

import {
  to = netbird_route.exit_node["luxembourg"]
  id = "dalths00rep000ev9te0"
}

import {
  to = netbird_route.exit_node["pristina"]
  id = "dan6r000rep000f29130"
}

import {
  to = netbird_route.exit_node["bruxelles"]
  id = "dbon5oo0rep000afjog0"
}

import {
  to = netbird_route.pristina_loopback
  id = "d9nkcoo0rep000ff0qc0"
}

import {
  to = netbird_nameserver_group.cloudflare
  id = "d9n1iao0rep000ci097g"
}

import {
  to = netbird_dns_zone.zone["anneraud.fr"]
  id = "d9n4rag0rep000c1eefg"
}

import {
  to = netbird_dns_zone.zone["minitrainstore.fr"]
  id = "d9n52700rep000c1equ0"
}

import {
  to = netbird_dns_record.bruxelles["mediatheque"]
  id = "d9n4rag0rep000c1eefg:d9n4sto0rep000c1ejcg"
}

import {
  to = netbird_dns_record.bruxelles["nuage"]
  id = "d9n4rag0rep000c1eefg:d9n53bg0rep000c1es6g"
}

import {
  to = netbird_dns_record.bruxelles["maison"]
  id = "d9n4rag0rep000c1eefg:dalu3tg0rep000evi440"
}

import {
  to = netbird_dns_record.bruxelles["wakapi"]
  id = "d9n4rag0rep000c1eefg:dalu4q00rep000evjde0"
}

import {
  to = netbird_dns_record.bruxelles["s"]
  id = "d9n4rag0rep000c1eefg:dalu5do0rep000evk6fg"
}

import {
  to = netbird_setup_key.github_xila
  id = "dbhr1s80rep000ev6njg"
}

import {
  to = netbird_identity_provider.zitadel
  id = "zitadel-davrje80rep000c60q9g"
}
