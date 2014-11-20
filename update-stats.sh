#!/bin/bash

#
# Script to update RRDs and create graphs.
#

# Auxiliary function to update an RRD file and create it if it doesn't
# already exist.
function update_rrd()
{
    filename=$1
    ds=$2
    value=$3
    
    if [ ! -f $filename ]; then
        echo creating $filename...
        rrdtool create $filename                    \
            --step 300                              \
            $ds                                     \
            RRA:AVERAGE:0.5:1:2016                  \
            RRA:AVERAGE:0.5:3:6720                  \
            RRA:AVERAGE:0.5:288:3650                \
            RRA:MIN:0.5:1:2016                      \
            RRA:MIN:0.5:3:6720                      \
            RRA:MIN:0.5:288:3650                    \
            RRA:MAX:0.5:1:2016                      \
            RRA:MAX:0.5:3:6720                      \
            RRA:MAX:0.5:288:3650
    fi

    rrdtool update $filename N:$value
}

# Auxiliary function to create a set of graphs with the desired
# resolution.
function create_graphs()
{
    start=$1
    suffix=$2
    
    rrdtool graph $webdir/solar$suffix.png \
        -w 800 -h 300 \
        -l 0 -u 120 \
        --start "$start" \
        --vertical-label "°C" \
        DEF:btemp=$rrddir/solar_buffer_temp.rrd:t:AVERAGE \
        CDEF:btempc=btemp,10,/ \
        VDEF:btempcur=btempc,LAST \
        VDEF:btempmin=btempc,MINIMUM \
        VDEF:btempmax=btempc,MAXIMUM \
        DEF:ptemp=$rrddir/solar_panel_temp.rrd:t:AVERAGE \
        CDEF:ptempc=ptemp,10,/ \
        VDEF:ptempcur=ptempc,LAST \
        VDEF:ptempmin=ptempc,MINIMUM \
        VDEF:ptempmax=ptempc,MAXIMUM \
        DEF:otemp=$rrddir/outside_temp.rrd:t:AVERAGE \
        CDEF:otempc=otemp,10,/ \
        VDEF:otempcur=otempc,LAST \
        VDEF:otempmin=otempc,MINIMUM \
        VDEF:otempmax=otempc,MAXIMUM \
        DEF:bttemp=$rrddir/buffer_top_temp.rrd:t:AVERAGE \
        CDEF:bttempc=bttemp,10,/ \
        VDEF:bttempcur=bttempc,LAST \
        VDEF:bttempmin=bttempc,MINIMUM \
        VDEF:bttempmax=bttempc,MAXIMUM \
        DEF:bmtemp=$rrddir/buffer_mid_temp.rrd:t:AVERAGE \
        CDEF:bmtempc=bmtemp,10,/ \
        VDEF:bmtempcur=bmtempc,LAST \
        VDEF:bmtempmin=bmtempc,MINIMUM \
        VDEF:bmtempmax=bmtempc,MAXIMUM \
        AREA:bttempc#ccccff:"Buffer top" \
        GPRINT:bttempcur:"  Current %4.1lf °C" \
        GPRINT:bttempmin:"Min %4.1lf °C" \
        GPRINT:bttempmax:"Max %4.1lf °C\l" \
        AREA:bmtempc#bbbbff:"Buffer mid" \
        GPRINT:bmtempcur:"  Current %4.1lf °C" \
        GPRINT:bmtempmin:"Min %4.1lf °C" \
        GPRINT:bmtempmax:"Max %4.1lf °C\l" \
        AREA:btempc#aaaaff:"Buffer solar" \
        GPRINT:btempcur:"Current %4.1lf °C" \
        GPRINT:btempmin:"Min %4.1lf °C" \
        GPRINT:btempmax:"Max %4.1lf °C\l" \
        LINE2:ptempc#ff0000:"Solar panel" \
        GPRINT:ptempcur:" Current %4.1lf °C" \
        GPRINT:ptempmin:"Min %4.1lf °C" \
        GPRINT:ptempmax:"Max %4.1lf °C\l" \
        LINE2:otempc#000000:"Air" \
        GPRINT:otempcur:"         Current %4.1lf °C" \
        GPRINT:otempmin:"Min %4.1lf °C" \
        GPRINT:otempmax:"Max %4.1lf °C\l"
    
    rrdtool graph $webdir/pumps$suffix.png \
        -w 800 -h 50 \
        -l 0 -u 100 \
        --start "$start" \
        --vertical-label % \
        DEF:spump=$rrddir/solar_pump_pct.rrd:pct:AVERAGE \
        DEF:wpump=$rrddir/water_pump_pct.rrd:pct:AVERAGE \
        AREA:spump#66000044:"Solar pump" \
        AREA:wpump#00006644:"Water pump"
    
    rrdtool graph $webdir/power$suffix.png \
        -w 800 -h 50 \
        --start "$start" \
        --vertical-label kWh \
        DEF:power=$rrddir/solar_power_total.rrd:power:AVERAGE \
        CDEF:powerc=power,10,/ \
        VDEF:powermin=powerc,FIRST \
        VDEF:powermax=powerc,LAST \
        CDEF:powertotal=powerc,POP,powermax,powermin,- \
        VDEF:vpt=powertotal,MAXIMUM \
        AREA:powerc#00ff0044:"Energy" \
        GPRINT:vpt:"      Period %4.1lf kWh\l"

    rrdtool graph $webdir/burner_temp$suffix.png \
        -w 800 -h 50 \
        -l 0 -u 120 \
        --start "$start" \
        --vertical-label "°C" \
        DEF:btemp=$rrddir/burner_temp.rrd:t:AVERAGE \
        CDEF:btempc=btemp,10,/ \
        VDEF:btempcur=btempc,LAST \
        VDEF:btempmin=btempc,MINIMUM \
        VDEF:btempmax=btempc,MAXIMUM \
        DEF:h=$rrddir/burner_hours.rrd:h:AVERAGE \
        CDEF:hc=h \
        VDEF:hmin=hc,FIRST \
        VDEF:hmax=hc,LAST \
        CDEF:htotal=hc,POP,hmax,hmin,- \
        VDEF:vht=htotal,MAXIMUM \
        DEF:s=$rrddir/burner_starts.rrd:starts:AVERAGE \
        CDEF:sc=s \
        VDEF:smin=sc,FIRST \
        VDEF:smax=sc,LAST \
        CDEF:stotal=sc,POP,hmax,hmin,- \
        VDEF:vst=stotal,MAXIMUM \
        DEF:i=$rrddir/burner_ignitions.rrd:ign:AVERAGE \
        CDEF:ic=i \
        VDEF:imin=ic,FIRST \
        VDEF:imax=ic,LAST \
        CDEF:itotal=ic,POP,hmax,hmin,- \
        VDEF:vit=itotal,MAXIMUM \
        AREA:btempc#ccccff:"Burner Temperature" \
        GPRINT:btempcur:"  Current %4.1lf °C" \
        GPRINT:btempmin:"Min %4.1lf °C" \
        GPRINT:btempmax:"Max %4.1lf °C\l" \
        GPRINT:vht:"  Burner %4.1lf h, " \
        GPRINT:vst:" %.0lf starts, " \
        GPRINT:vit:" %.0lf ignitions\l"
}

function op_update()
{
  # Get values
  $workdir/get-values.pl $workdir/oekofen.cfg > $tmpfile
  if [ $? -ne 0 ]; then
    echo "get-values.pl returned $?, aborting."
    rm $tmpfile
    exit 1
  fi

  # Set variables
  source $tmpfile

  rm $tmpfile

  # Update RRDs

  # Various temperatures
  update_rrd $rrddir/outside_temp.rrd DS:t:GAUGE:600:-1500:1500 $outside_temp
  update_rrd $rrddir/solar_panel_temp.rrd DS:t:GAUGE:600:-1500:1500 $solar_panel_temp
  update_rrd $rrddir/solar_buffer_temp.rrd DS:t:GAUGE:600:-1500:1500 $solar_buffer_temp
  update_rrd $rrddir/solar_flow_temp.rrd DS:t:GAUGE:600:-1500:1500 $solar_flow_temp
  update_rrd $rrddir/solar_return_temp.rrd DS:t:GAUGE:600:-1500:1500 $solar_return_temp
  update_rrd $rrddir/buffer_top_temp.rrd DS:t:GAUGE:600:-1500:1500 $buffer_top_temp
  update_rrd $rrddir/buffer_mid_temp.rrd DS:t:GAUGE:600:-1500:1500 $buffer_mid_temp

  # Heater temperatures
  update_rrd $rrddir/boiler_temp.rrd DS:t:GAUGE:600:-10000:10000 $boiler_temp

  # Burner counters and temperature
  update_rrd $rrddir/burner_hours.rrd DS:h:GAUGE:600:0:10000000 $burner_hours
  update_rrd $rrddir/burner_ignitions.rrd DS:ign:GAUGE:600:0:10000000 $burner_ignitions
  update_rrd $rrddir/burner_starts.rrd DS:starts:GAUGE:600:0:10000000 $burner_starts
  update_rrd $rrddir/burner_temp.rrd DS:t:GAUGE:600:-10000:10000 $burner_temp

  # Solar flow
  update_rrd $rrddir/solar_flow_rate.rrd DS:f:GAUGE:600:-1000:1000 $solar_flow_rate

  # Instantaneous power
  update_rrd $rrddir/solar_power_current.rrd DS:power:GAUGE:600:0:10000000 $solar_power_current

  # Day and total energy, store counter as gauge
  update_rrd $rrddir/solar_power_day.rrd DS:power:GAUGE:600:0:10000000 $solar_power_day
  update_rrd $rrddir/solar_power_total.rrd DS:power:GAUGE:600:0:10000000 $solar_power_total

  # Pump power percent (0-100)
  update_rrd $rrddir/solar_pump_pct.rrd DS:pct:GAUGE:600:0:1000 $solar_pump_pct
  update_rrd $rrddir/water_pump_pct.rrd DS:pct:GAUGE:600:0:1000 $water_pump_pct
}

function op_graphs()
{
  # Create graphs
  create_graphs "-24 hours" ""
  create_graphs "-7 days" .7d
  create_graphs "-30 days" .30d
}

tmpfile=`mktemp`
workdir=/usr/local/oekofen-stats
rrddir=$workdir/rrd
webdir=$workdir/web

case "$1" in
  update)
    op_update  
    ;;
  graphs)
    op_graphs
    ;;
  help)
    echo "Usage: $0 [update|graphs]"
    exit 1
    ;;
  *)
    op_update
    op_graphs
    ;;
esac

exit 0

