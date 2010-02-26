#!/usr/bin/perl
# tvsd.pl - TVS auto-syndicated news portal...

use strict;
use warnings;

my $daemon = TVSD->new(8888);
$daemon->run;

package TVSD;

use lib 'library/';
use Controller;

use HTTP::Server::Simple::CGI;
use base qw/ HTTP::Server::Simple::CGI /;

my %dispatch = (

    '/index.pl' => \&start_tvs,

);

sub handle_request {

    my ( $self, $cgi ) = @_;

    my $path    = $cgi->path_info();
    my $handler = $dispatch{$path};

    #if ( ref($handler) eq 'CODE' ) {

        print "HTTP/1.0 200 OK\r\n";
        $handler->($cgi);
    #}
    #else {
    #
    #    print "HTTP/1.0 404 Not found\r\n";
    #    print $cgi->header, $cgi->start_html('Not found'), $cgi->h1('Not found'), $cgi->end_html;
    #}

}

sub start_tvs {

    my $cgi = shift;
    return if !ref $cgi;

    my $ctrl = new Controller;
    $ctrl->process();

}

1;
