# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003-2009 SvenDowideit@fosiki.com

#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#

package Foswiki::Plugins::SoapClientPlugin;
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $exampleCfgVar
);

$VERSION    = '$Rev$';
$RELEASE    = '1.200';
$pluginName = 'SoapClientPlugin';    # Name of this Plugin

use SOAP::Lite;
use Error qw( :try );

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = &Foswiki::Func::getPreferencesValue("EMPTYPLUGIN_EXAMPLE")
      || "default";

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub doSoapRequest {
    my $service = Foswiki::Func::extractNameValuePair( $_[0], "service" );
    my $call_with_params = Foswiki::Func::extractNameValuePair( $_[0], "call" );
    my $format = Foswiki::Func::extractNameValuePair( $_[0], "format" );
    my $text = "";

    #       my $service = SOAP::Lite
    #         -> service($service);
    #         -> service('http://gforge.org/soap/SoapAPI.php?wsdl');
    #       @results = @{$service->getPublicProjectNames()};

    #$call="getPublicProjectNames";
    #$service= "http://gforge.org/soap/SoapAPI.php";

    my $call = $call_with_params;
    $call =~ /(.*)[(](.*)[)]/;
    $call = $1;
    my $params = $2;

    try {
        my $method = SOAP::Data->name($call)->attr( { xmlns => $service } );

        my @parameters = split( /,/, $params );
        my $res =
          SOAP::Lite->service( $service . "?wsdl" )->proxy($service)
          ->call( $method => @parameters );

        $text = $text . "{$params}";
        foreach $result (@parameters) {
            $text = $text . "($result);";
        }

        if ( ref $res->result eq "SCALAR" ) {
            $text = $text . "scalar\n";
        }
        elsif ( ref $res->result eq "ARRAY" ) {
            @results = @{ $res->result };
            foreach $result (@results) {
                my $tmp = $format;
                $tmp =~ s/\$list_element/$result/geo;
                $text = $text . $tmp;
            }
        }
        elsif ( ref $res->result eq "HASH" ) {

# split up the format, finding all the $field() bits, and then use them in the HASH
            $text = $format;
            my $mmm = "v";
            $text =~ s/\$struct\(([^)]*)\)/getHash($res->result, $1)/ge;
        }
        else {
            $text = $test . "mmm" . ref $res->result . "\n";
        }
    }
    catch Error::Simple with {

        #TODO: some sort of error response
        my $e   = shift;
        my $err = "$e";
        $err =~ s/\n/<br \>/g;
        $text = "\n<code>\nError during SOAP operation: \n$err\n</code>";
    }

    $text =~ s/\$n/\n/g;

    return $text;
}

# =========================
sub getHash {
    return $_[0]->{ $_[1] };
}

# =========================
sub startRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    Foswiki::Func::writeDebug("- ${pluginName}::startRenderingHandler( $_[1] )")
      if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;

    $_[0] =~ s/%SOAP{(.*?)}%/doSoapRequest($1)/geo;
}

# =========================

1;
