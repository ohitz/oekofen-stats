oekofen-stats
=============

OLD VERSION: Does "screen scraping" on the ÖkoFEN web
interface. Superseded by a version which uses the internal log
generatd by the the controller.

Simple scripts to fetch statistics from a ÖkoFEN Pellematic Smart
solar pellet heating connected to our LAN.

We want to periodically retrieve interesting values in order to see
how our heating performs.

Requirements
------------

This requires perl with the `JSON`, `WWW::Mechanize` and
`Config::Simple` perl modules, as well as `rrdtool` for storing the
data and graphing.

Components
----------

This is relatively simple for now:

* The `get_values.pl` perl script connects to our heating web
  interface and fetches the values configured in `oekofen.cfg`.

* The `update-stats.sh` shell script is called periodially. It calls
  `get_values.pl`, stores the values in RRDs and creates some graphs.

Install
-------

To install, copy the whole lot to `/usr/local/oekofen-stats/` and

* Copy `oekofen.cfg.dist` to `oekofen.cfg`

* Edit `oekofen.cfg` to change the correct URL, username and password
  of your Pellematic smart

* By default, graphs are stored to `/usr/local/oekofen-stats/web/`. If
  you want to change this, edit the `update-stats.sh` shell script.

* Call `update-stats.sh` manually. This will create RRDs in
  `/usr/local/oekofen-stats/rrd/` and graphs in
  `/usr/local/oekofen-stats/web/`.

* Configure your webserver to serve `/usr/local/oekofen-stats/web/`

* If you are happy with the result, install the cron job in order to
  fetch new values every 5 minutes:
  `ln -s /usr/local/oekofen-stats/cron/local-oekofen-stats /etc/cron.d/`
