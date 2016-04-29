#!/usr/bin/perl

use Getopt::Long;
use POSIX::strptime;
use Date::Format;
use Time::Local;
use Text::CSV;
use LWP::UserAgent;
use Config::Simple;
use feature 'state';
use strict;

my $workdir = "/usr/local/oekofen-stats/";

my $cfg_debug_on = 0;
my $cfg_fetch_only = 0;
my $cfg_config = "$workdir/oekofen.cfg";

my $csvdir = "$workdir/csv/";

if (!GetOptions( "debug" => \$cfg_debug_on,
                 "fetch-only" => \$cfg_fetch_only,
                 "config=s" => \$cfg_config )) {
  print "Usage: $0 [--debug] [--fetch-only] [--config=oekofen.cfg]\n";
  exit 1;
}

# Load configuration.
my $cfg = new Config::Simple($cfg_config) or
    die Config::Simple->error();

my $cfg_controller_base = $cfg->param("default.controller_url");
my $cfg_controller_logdir = "/logfiles/pelletronic/";

my $ua = LWP::UserAgent->new;

my @files;

my $csv = Text::CSV->new({ binary => 1,
                           sep_char => ';',
                           keep_meta_info => 1,
                           auto_diag => 1 });

#
# Get the list of files.
#
my $url = sprintf("%s%s", $cfg_controller_base.$cfg_controller_logdir);
my $response = $ua->get($url);
if ($response->code != 200) {
  die sprintf("Unable to access %s, error %s.\n",
              $url, $response->code);
}
my $content = $response->decoded_content;

while ($content =~ qr|"$cfg_controller_logdir(touch_\d{8}\.csv)"|) {
  my $file = $1;
  $content =~ s/$file//;
  push @files, $file;
}

debug("%d logs available on pelletronic controller.\n", scalar @files);

#
# Check for each of the files if it exists and if it is complete.
#
foreach my $file (@files) {
  debug("Checking log file %s.\n", $file);
  
  if (-f "$csvdir/$file") {
    debug("Log file %s exists, checking last row now.\n", $file);

    # The file exists. Now load the last line to check which day it refers to.
    # It should refer to the last minute of the day or to the first minute of
    # the next day. If it doesn't, this means that the file is not complete yet
    # and should be downloaded.

    open my $fh, "<", "$csvdir/$file"
        or die "$csvdir/$file: $!";

    my $last_row;
    
    # First line contains column names.
    $csv->column_names($csv->getline($fh));

    while (my $row = $csv->getline_hr($fh)) {
      # Skip blank lines.
      if ($csv->is_missing(1)) {
        next;
      }

      $last_row = $row;
    }

    close $fh;

    if ($last_row) {
      my $data = decode_row($last_row);

      # Convert date and time to seconds since unix epoch
      my $time = timelocal POSIX::strptime($data->{"date"}." ".$data->{"time"}, '%d.%m.%Y %H:%M:%S');

      # Add 1 minute (in case the file refers to the last minute of 
      # the day).
      $time += 60;

      # Convert to YYYYMMDD.
      my $date = time2str("%Y%m%d", $time);

      debug("Log file %s date in last row is %s.\n", $file, $date);
      
      # Check if this is the date of the current or of the next day.
      if ($file !~ /$date/) {
        # File is complete, proceed to the next file.
        debug("Log file %s is complete.\n", $file);
        next;
      }
    } else {
      debug("No last row found in log file %s.\n", $file);
    }
  }

  # The file either doesn't exist or is imcomplete. Download it.
  debug("Log file %s either doesn't exist or is incomplete.\n", $file);

  my $url = sprintf("%s%s%s",
                    $cfg_controller_base,
                    $cfg_controller_logdir,
                    $file);
  debug("Downloading %s.\n", $url);
  my $response = $ua->get($url);
  if ($response->code != 200) {
    die sprintf("Unable to access %s, error %s.\n",
                $url, $response->code);
  }
  my $content = $response->decoded_content;

  # If the file already exists, check if the downloaded one is bigger.
  if ((-s "$csvdir/$file") < length($content)) {
    # The file either doesn't exist or is imcomplete. Download it.
    debug("Log file %s has changed, storing it.\n", $file);

    # Store downloaded file.  
    open my $fh, ">", "$csvdir/$file";
    print $fh $content;
    close $fh;

    # Process
    if (!$cfg_fetch_only) {
      debug("Processing %s.\n", $file);
      `$workdir/process-log.pl $csvdir/$file`;
    }    
  } else {
    debug("Log file %s has not changed.\n", $file);
  }
  last;  
}

exit 0;

sub debug
{
  my $format = shift;
  my (@args) = @_;

  if ($cfg_debug_on) {
    printf($format, @args);
  }
}

sub decode_row
{
  # Columns information.
  state $cols = [
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
      "field" => "AT [\xb0C]",
      "type" => "number",
    },
    {
      # Heating circuit flow actual
      "name" => "hc_flow_temp_actual",
      "field" => "HK1 VL Ist[\xb0C]",
      "type" => "number",
    },
    {
      # Heating circuit flow nominal
      "name" => "hc_flow_temp_nominal",
      "field" => "HK1 VL Soll[\xb0C]",
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
      "field" => "PE1 Abgastemp[\xb0C]",
      "type" => "number",
    },
    {
      # buffer_top_temp
      "name" => "buffer_top_temp",
      "field" => "PU1 TPO Ist[\xb0C]",
      "type" => "number",
    },
    {
      # buffer_mid_temp
      "name" => "buffer_mid_temp",
      "field" => "PU1 TPM Ist[\xb0C]",
      "type" => "number",
    },
    {
      # buffer_solar_temp
      "name" => "buffer_solar_temp",
      "field" => "SK1 SPUnten[\xb0C]",
      "type" => "number",
    },
    {
      # solar_panel_temp
      "name" => "solar_panel_temp",
      "field" => "SK1 Koll[\xb0C]",
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
      "field" => "PE1 Abgastemp[\xb0C]",
      "type" => "number",
    },
  ];

  my $row = shift;

  # Decoded data
  my $data;
    
  foreach my $col (@{ $cols }) {
    my $raw = $row->{$col->{"field"}};
    if ($col->{"type"} eq "date") {
      $data->{$col->{"name"}} = $raw;
    } elsif ($col->{"type"} eq "time") {
      $data->{$col->{"name"}} = $raw;
    } else {
      $raw =~ s/,/./;
      $data->{$col->{"name"}} = $raw;
    }
  }

  return $data;  
}

sub get_last_record_time
{
  my $file = shift;

  
}
