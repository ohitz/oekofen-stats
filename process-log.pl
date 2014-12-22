#!/usr/bin/perl

use POSIX::strptime;
use Time::Local;
use Text::CSV;
use strict;

my $workdir = "/usr/local/oekofen-stats/";

if ($#ARGV < 0) {
  printf STDERR "Usage: $0 touch.csv\n";
  exit 1;
}

my $rrddir = "$workdir/rrd/";
my $webdir = "$workdir/web/";

my $degc = "[\xb0C]";

my $csv = Text::CSV->new({ binary => 1,
                           sep_char => ';',
                           keep_meta_info => 1,
                           auto_diag => 1 });

# Columns to fetch.
my $cols = [
  {
    # Date
    "name" => "date",
    "field" => "Datum ",
    "type" => "date"
  },
  {
    # Time
    "name" => "time",
    "field" => "Zeit ",
    "type" => "time"
  },
  {
    # Outside temperature
    "name" => "outside_temp",
    "field" => "AT $degc",
    "type" => "number",
  },
  {
    # Heating circuit flow actual
    "name" => "hc_flow_temp_actual",
    "field" => "HK1 VL Ist$degc",
    "type" => "number",
  },
  {
    # Heating circuit flow nominal
    "name" => "hc_flow_temp_nominal",
    "field" => "HK1 VL Soll$degc",
    "type" => "number",
  },
  {
    # Heating curcuit pump
    "name" => "hc_pump",
    "field" => "HK1 Pumpe",
    "type" => "number",
  },
  {
    # burner_temp
    "name" => "burner_temp",
    "field" => "PE1 Abgastemp$degc",
    "type" => "number",
  },
  {
    # buffer_top_temp
    "name" => "buffer_top_temp",
    "field" => "PU1 TPO Ist$degc",
    "type" => "number",
  },
  {
    # buffer_mid_temp
    "name" => "buffer_mid_temp",
    "field" => "PU1 TPM Ist$degc",
    "type" => "number",
  },
  {
    # buffer_solar_temp
    "name" => "buffer_solar_temp",
    "field" => "SK1 SPUnten$degc",
    "type" => "number",
  },
  {
    # solar_panel_temp
    "name" => "solar_panel_temp",
    "field" => "SK1 Koll$degc",
    "type" => "number",
  },
  {
    # solar_power
    "name" => "solar_power",
    "field" => "Ertrag1 Aktuell[kW]",
    "type" => "number",
  },
  {
    # burner_temp
    "name" => "burner_temp",
    "field" => "PE1 Abgastemp$degc",
    "type" => "number",
  },
];

my $outside_temp = rrd_init("$rrddir/outside_temp.rrd", "DS:t:GAUGE:600:-150:150");

my $buffer_top_temp = rrd_init("$rrddir/buffer_top_temp.rrd", "DS:t:GAUGE:600:-150:150");
my $buffer_mid_temp = rrd_init("$rrddir/buffer_mid_temp.rrd", "DS:t:GAUGE:600:-150:150");
my $buffer_solar_temp = rrd_init("$rrddir/buffer_solar_temp.rrd", "DS:t:GAUGE:600:-150:150");

my $solar_panel_temp = rrd_init("$rrddir/solar_panel_temp.rrd", "DS:t:GAUGE:600:-150:150");

my $solar_power = rrd_init("$rrddir/solar_power.rrd", "DS:p:GAUGE:600:-150:150");

my $burner_temp = rrd_init("$rrddir/burner_temp.rrd", "DS:t:GAUGE:600:0:800");

my $hc_pump = rrd_init("$rrddir/hc_pump.rrd", "DS:on:GAUGE:600:0:1");

my $hc_flow_temp_actual = rrd_init("$rrddir/hc_flow_temp_actual.rrd", "DS:t:GAUGE:600:-150:150");
my $hc_flow_temp_nominal = rrd_init("$rrddir/hc_flow_temp_nominal.rrd", "DS:t:GAUGE:600:-150:150");

foreach my $file (@ARGV) {
  open my $fh, "<", $file
      or die "$file: $!";

  # First line contains column names.
  $csv->column_names($csv->getline($fh));
  
  while (my $row = $csv->getline_hr($fh)) {
    # Skip blank lines.
    if ($csv->is_missing(1)) {
      next;
    }
    
    # Load data
    my $data;
    
    foreach my $col (@{ $cols }) {
      my $raw = $row->{$col->{"field"}};
      if ($col->{"type"} eq "date") {
        $data->{$col->{"name"}} = $raw;
      } elsif ($col->{"type"} eq "time") {
        $data->{$col->{"name"}} = $raw;
      } else {
        $data->{$col->{"name"}} = get_number($raw);
      }
    }
    
    # Convert date and time to seconds since unix epoch
    my $time = timelocal POSIX::strptime($data->{"date"}." ".$data->{"time"}, '%d.%m.%Y %H:%M:%S');
    
    rrd_update($outside_temp, $time, $data->{"outside_temp"});
    
    rrd_update($buffer_top_temp, $time, $data->{"buffer_top_temp"});
    rrd_update($buffer_mid_temp, $time, $data->{"buffer_mid_temp"});
    rrd_update($buffer_solar_temp, $time, $data->{"buffer_solar_temp"});
    
    rrd_update($solar_panel_temp, $time, $data->{"solar_panel_temp"});
    rrd_update($solar_power, $time, $data->{"solar_power"});
    
    rrd_update($burner_temp, $time, $data->{"burner_temp"});
    
    rrd_update($hc_pump, $time, $data->{"hc_pump"});
    
    rrd_update($hc_flow_temp_actual, $time, $data->{"hc_flow_temp_actual"});
    rrd_update($hc_flow_temp_nominal, $time, $data->{"hc_flow_temp_nominal"});
  }

  close $fh;
}

rrd_commit($outside_temp);

rrd_commit($buffer_top_temp);
rrd_commit($buffer_mid_temp);
rrd_commit($buffer_solar_temp);

rrd_commit($solar_panel_temp);
rrd_commit($solar_power);

rrd_commit($burner_temp);

rrd_commit($hc_pump);

rrd_commit($hc_flow_temp_actual);
rrd_commit($hc_flow_temp_nominal);

create_graphs("-24 hours", "now", "");
create_graphs("-7 days", "now", ".7d");
create_graphs("-30 days", "now", ".30d");

#formatTexts: " Dauerlauf|Start|Zuendung|Softstart|Leistungsbrand|Nachlauf|Aus|Saugen|! Asche !|! Pellets !|Pell Switch|StÃ¶rung|Einmessen|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|1|Aus|Aus|Aus|Aus|Aus"

exit 0;

sub get_number
{
  my $x = shift;
  $x =~ s/,/./;
  return $x;
}

sub rrd_init
{
  my $file = shift;
  my $spec = shift;

  my $rrd = {
    "file" => $file,
    "spec" => $spec,
    "updates" => [],
    "last" => 0,
  };
  
  if (-f $rrd->{"file"}) {
    my $cmd = sprintf("rrdtool last %s",
                      $rrd->{file});
    $rrd->{"last"} = int `$cmd`;
  }
  
  return $rrd;
}

sub rrd_update
{
  my $rrd = shift;
  my $time = shift;
  my $value = shift;

  if ($rrd->{"last"} >= $time) {
    return;
  }

  $rrd->{"last"} = $time;
  
  if (!defined($rrd->{"min_time"}) || ($time < $rrd->{"min_time"})) {
    $rrd->{"min_time"} = $time;
  }

  push @{ $rrd->{"updates"} }, sprintf("%s:%s", $time, $value);
}

sub rrd_commit
{
  my $rrd = shift;

  if (! -f $rrd->{"file"}) {
    my $cmd = sprintf("rrdtool create %s --start=%d --step=300 %s ".
                      "RRA:AVERAGE:0.5:1:2016 ".
                      "RRA:AVERAGE:0.5:3:6720 ".
                      "RRA:AVERAGE:0.5:288:3650 ".
                      "RRA:MIN:0.5:1:2016 ".
                      "RRA:MIN:0.5:3:6720 ".
                      "RRA:MIN:0.5:288:3650 ".
                      "RRA:MAX:0.5:1:2016 ".
                      "RRA:MAX:0.5:3:6720 ".
                      "RRA:MAX:0.5:288:3650",
                      $rrd->{"file"},
                      $rrd->{"min_time"}-1,
                      $rrd->{"spec"});
    `$cmd`;
  }

  my @updates = @{ $rrd->{"updates"} };
  while (0 < scalar @updates) {
    my @u = splice(@updates, 0, 1000);
    
    my $cmd = sprintf("rrdtool update %s %s > /dev/null 2>&1",
                      $rrd->{"file"},
                      join " ", @u);
    `$cmd`;
  }

#  my $cmd = sprintf("rrdtool update %s %s > /dev/null 2>&1",
#                    $rrd->{"file"},
#                    join " ", @{ $rrd->{"updates"} });
#  `$cmd`;
}

sub create_graphs
{
  my $start = shift;
  my $end = shift;
  my $suffix = shift;
  my $cmd;
  
  $cmd = sprintf("rrdtool graph %s/temp%s.png ".
                 "-w 800 -h 120 ".
                 "-l 0 -u 100 ".
                 "--start '%s' ".
                 "--end '%s' ".
                 "--vertical-label '°C' ".
                 "DEF:otemp=$rrddir/outside_temp.rrd:t:AVERAGE ".
                 "VDEF:otempcur=otemp,LAST ".
                 "VDEF:otempmin=otemp,MINIMUM ".
                 "VDEF:otempmax=otemp,MAXIMUM ".
                 "DEF:bttemp=$rrddir/buffer_top_temp.rrd:t:AVERAGE ".
                 "VDEF:bttempcur=bttemp,LAST ".
                 "VDEF:bttempmin=bttemp,MINIMUM ".
                 "VDEF:bttempmax=bttemp,MAXIMUM ".
                 "DEF:bmtemp=$rrddir/buffer_mid_temp.rrd:t:AVERAGE ".
                 "VDEF:bmtempcur=bmtemp,LAST ".
                 "VDEF:bmtempmin=bmtemp,MINIMUM ".
                 "VDEF:bmtempmax=bmtemp,MAXIMUM ".
                 "DEF:bstemp=$rrddir/buffer_solar_temp.rrd:t:AVERAGE ".
                 "VDEF:bstempcur=bstemp,LAST ".
                 "VDEF:bstempmin=bstemp,MINIMUM ".
                 "VDEF:bstempmax=bstemp,MAXIMUM ".
                 "DEF:stemp=$rrddir/solar_panel_temp.rrd:t:AVERAGE ".
                 "VDEF:stempcur=stemp,LAST ".
                 "VDEF:stempmin=stemp,MINIMUM ".
                 "VDEF:stempmax=stemp,MAXIMUM ".
                 "AREA:bttemp#ccccff:'Buffer Top' ".
                 "GPRINT:bttempcur:'    Current %%4.1lf °C' ".
                 "GPRINT:bttempmin:'Min %%4.1lf °C' ".
                 "GPRINT:bttempmax:'Max %%4.1lf °C\\l' ".
                 "AREA:bmtemp#bbbbff:'Buffer Middle' ".
                 "GPRINT:bmtempcur:' Current %%4.1lf °C' ".
                 "GPRINT:bmtempmin:'Min %%4.1lf °C' ".
                 "GPRINT:bmtempmax:'Max %%4.1lf °C\\l' ".
                 "AREA:bstemp#aaaaff:'Buffer Solar' ".
                 "GPRINT:bstempcur:'  Current %%4.1lf °C' ".
                 "GPRINT:bstempmin:'Min %%4.1lf °C' ".
                 "GPRINT:bstempmax:'Max %%4.1lf °C\\l' ".
                 "LINE:otemp#00ff00:Outside ".
                 "GPRINT:otempcur:'       Current %%4.1lf °C' ".
                 "GPRINT:otempmin:'Min %%4.1lf °C' ".
                 "GPRINT:otempmax:'Max %%4.1lf °C\\l' ",
                 $webdir, $suffix, $start, $end);
  `$cmd`;

  $cmd = sprintf("rrdtool graph %s/hc%s.png ".
                 "-w 800 -h 100 ".
                 "-l 0 -u 50 ".
                 "--rigid ".
                 "--start '%s' ".
                 "--end '%s' ".
                 "--vertical-label '°C' ".
                 "DEF:ntemp=$rrddir/hc_flow_temp_nominal.rrd:t:AVERAGE ".
                 "VDEF:ntempcur=ntemp,LAST ".
                 "VDEF:ntempmin=ntemp,MINIMUM ".
                 "VDEF:ntempmax=ntemp,MAXIMUM ".
                 "DEF:atemp=$rrddir/hc_flow_temp_actual.rrd:t:AVERAGE ".
                 "VDEF:atempcur=atemp,LAST ".
                 "VDEF:atempmin=atemp,MINIMUM ".
                 "VDEF:atempmax=atemp,MAXIMUM ".
                 "DEF:pump=$rrddir/hc_pump.rrd:on:AVERAGE ".
                 "CDEF:pumpc=pump,1000,\\* ".
                 "LINE:ntemp#00ff00aa:'Nominal' ".
                 "GPRINT:ntempcur:' Current %%4.1lf °C' ".
                 "GPRINT:ntempmin:'Min %%4.1lf °C' ".
                 "GPRINT:ntempmax:'Max %%4.1lf °C\\l' ".
                 "LINE:atemp#ff0000aa:'Actual' ".
                 "GPRINT:atempcur:'  Current %%4.1lf °C' ".
                 "GPRINT:atempmin:'Min %%4.1lf °C' ".
                 "GPRINT:atempmax:'Max %%4.1lf °C\\l' ".
                 "AREA:pumpc#9b9b9b44:'Heating circuit pump on/off'",
                 $webdir, $suffix, $start, $end);
  `$cmd`;

  $cmd = sprintf("rrdtool graph %s/solar%s.png ".
                 "-w 800 -h 120 ".
                 "-l 0 -u 100 ".
                 "--rigid ".
                 "--start '%s' ".
                 "--end '%s' ".
                 "--vertical-label 'Temperature °C' ".
                 "--right-axis 50:0 ".
                 "--right-axis-label 'Power W' ".
                 "--right-axis-format '%%4.0lf' ".
                 "DEF:p=$rrddir/solar_power.rrd:p:AVERAGE ".
                 "CDEF:pscaled=p,50,* ".
                 "CDEF:pkws=p,3600,/ ".
                 "VDEF:pcur=p,LAST ".
                 "VDEF:pmin=p,MINIMUM ".
                 "VDEF:pmax=p,MAXIMUM ".
                 "DEF:t=$rrddir/solar_panel_temp.rrd:t:AVERAGE ".
                 "VDEF:tcur=t,LAST ".
                 "VDEF:tmin=t,MINIMUM ".
                 "VDEF:tmax=t,MAXIMUM ".
                 "AREA:t#ffaa00ff:'Panel Temperature' ".
                 "GPRINT:tcur:'Current %%4.1lf °C' ".
                 "GPRINT:tmin:'Min %%4.1lf °C' ".
                 "GPRINT:tmax:'Max %%4.1lf °C\\l' ".
                 "AREA:pscaled#ff000044:'Power            ' ".
                 "GPRINT:pcur:'Current %%4.1lf kW' ".
                 "GPRINT:pmin:'Min %%4.1lf kW' ".
                 "GPRINT:pmax:'Max %%4.1lf kW\\l' ".
                 "COMMENT:' \\l' ".
                 "VDEF:ptotal=pkws,TOTAL ".
                 "GPRINT:ptotal:'  Total solar energy during period\\: %%2.1lf kWh\\l'"
                 ,
                 $webdir, $suffix, $start, $end);
  `$cmd`;

  $cmd = sprintf("rrdtool graph %s/burner%s.png ".
                 "-w 800 -h 100 ".
                 "-l 0 -u 800 ".
                 "--start '%s' ".
                 "--end '%s' ".
                 "--vertical-label '°C' ".
                 "DEF:btemp=$rrddir/burner_temp.rrd:t:AVERAGE ".
                 "VDEF:btempcur=btemp,LAST ".
                 "VDEF:btempmin=btemp,MINIMUM ".
                 "VDEF:btempmax=btemp,MAXIMUM ".
                 "CDEF:btime=btemp,100,GT,3600,/ ".
                 "AREA:btemp#00ff00aa:'Temperature' ".
                 "GPRINT:btempcur:' Current %%4.1lf C' ".
                 "GPRINT:btempmin:'Min %%4.1lf C' ".
                 "GPRINT:btempmax:'Max %%4.1lf C\\l' ".
                 "VDEF:btimetotal=btime,TOTAL ".
                 "COMMENT:' \\l' ".
                 "GPRINT:btimetotal:'  Total operating time during period\\: %%3.1lfh\\l' "
                 ,
                 $webdir, $suffix, $start, $end);
  `$cmd`;
}
