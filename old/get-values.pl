#!/usr/bin/perl
#
# Copyright (C) 2014 Oliver Hitz <oliver@net-track.ch>
#
# Simple script to fetch values from an ÖkoFEN Pellematic Smart
# microcontroller.
#

use JSON;
use WWW::Mechanize;
use Config::Simple;
use strict;

if ($#ARGV != 0) {
  printf STDERR "Usage: $0 oekofen.cfg\n";
  exit 1;
}

# Load configuration.
my $cfg = new Config::Simple($ARGV[0]) or
    die Config::Simple->error();

# Controller address and login credentials.
my $controller_url = $cfg->param("default.controller_url")
    or die "controller_url undefined!";

my $controller_user = $cfg->param("default.controller_user")
    or die "controller_user undefined!";
my $controller_password = $cfg->param("default.controller_password")
    or die "controller_password undefined!";

# Get list of variables to request from the controller.
my $variables = $cfg->get_block("variables");

# Get the controller's login form.
my $mech = WWW::Mechanize->new();
$mech->add_header("Accept" => "application/json, text/javascript, */*; q=0.01");
$mech->add_header("Accept-Language" => "de");

$mech->get($controller_url."/login.cgi");

# Submit login form.
$mech->form_with_fields( ( "username", "password" ) );
$mech->field("username", $controller_user);
$mech->field("password", $controller_password);
$mech->field("language", "de");
$mech->submit();

# Request the specified fields.
$mech->post($controller_url."/?action=get&attr=1",
            Content => encode_json([ values %{ $variables } ]));

# Construct a name -> value hash.
my %result = map { $_->{name} => $_->{value} } @{ decode_json($mech->content()) };

# Print variable=value pairs.
foreach my $name (keys %{ $variables }) {
  printf("%s=%s\n",
         $name,
         $result{$variables->{$name}});
}

exit 0;
