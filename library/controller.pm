# controller.pm - TVS auto-syndicated news portal...

package Controller;

use warnings;
use strict;

# initial CGI::Builder instantiation and configuration...
use CGI::Builder qw/ CGI::Builder::LogDispatch CGI::Builder::HTMLtmpl /;

# required tvs modules...
use lib 'library';
use model;

# b e g i n ::: 'initialization' phase...

# handler for initialization...
sub OH_init {

    # preamble...
    my ($self) = @_;

    # initiate the Model class...
    $self->{model} = new Model;

    # assign initial CGI::Builder arguments...
    $self->cgi_page_param = 'view';
    $self->page_name      = $self->{model}->{config}->{default_page};

    # assign initial CGI::Builder::LogDispatch arguments.
    # this value is currently set to 'debug' for development purposes...
    $self->logger_config( 'min_level' => 'debug' );

    # assign initial CGI::Builder::HTMLtmpl arguments...
    $self->page_suffix = '.xhtml';
    $self->ht_new_args(
        path              => ["styles/$self->{model}->{styles}->{current_style}/"],
        die_on_bad_params => 0,
        cache             => 0,
    );

}

# b e g i n ::: 'fixup' phase...

# handler for fixing up any possible issues prior to sending data
# to the client. it also currently handles any  external CGI
# requests given to tvs...
sub OH_fixup {

    # preamble...
    my ($self) = @_;

    # output any errors to Apache's error.log via CGI::Builder::LogDispatch...
    $self->logger->debug('tvs :: debug level error handling initialized');
    if ( $self->page_error ) { $self->logger->error( 'tvs :: there is a problem! - ' . "$!" ) }

    # voting request...
    if ( $self->page_name =~ /vote/x ) {

        # parse request then send a 'do_vote' request...
        my ( undef, $name, $tbl_id ) = split( /:/, $self->page_name );
        $self->{model}->do_vote( name => $name, tbl_id => $tbl_id );
    }

}

# b e g i n ::: 'page handler' phase...

# page handler for 'home' page requests...
sub PH_home {

    # preamble...
    my ($self) = @_;

    # build page content...
    my @page_data = {

        # section statistics...
        'featured-count'   => int @{ $self->{model}->get_articles( list => 'featured' ) },
        'watch_list-count' => int @{ $self->{model}->get_articles( list => 'watch_list' ) },
        'inbox-count'      => int @{ $self->{model}->get_articles( list => 'inbox' ) },

        # random articles...
        'random_articles' => $self->{model}->get_articles( list => 'watch_list', random_articles => 5 ),

        # page articles...
        'home' => $self->{model}->get_articles( list => 'home' ),

        # page title...
        'page_title' => 'Viewing... \'Home\'',
    };

    # now send data to the client...
    $self->ht_param(@page_data);

}

# page handler for 'featured' page requests...
sub PH_featured {

    # preamble...
    my ($self) = @_;

    # build page content...
    my @page_data = {

        # section statistics...
        'featured-count'   => int @{ $self->{model}->get_articles( list => 'featured' ) },
        'watch_list-count' => int @{ $self->{model}->get_articles( list => 'watch_list' ) },
        'inbox-count'      => int @{ $self->{model}->get_articles( list => 'inbox' ) },

        # random articles...
        'random_articles' => $self->{model}->get_articles( list => 'watch_list', random_articles => 5 ),

        # page articles...
        'featured' => $self->{model}->get_articles( list => 'featured' ),

        # page title...
        'page_title' => 'Viewing... \'Featured\'',
    };

    # now send data to the client...
    $self->ht_param(@page_data);

}

# page handler for 'watch list' page requests...
sub PH_watch_list {

    # preamble...
    my ($self) = @_;

    # build page content...
    my @page_data = {

        # section statistics...
        'featured-count'   => int @{ $self->{model}->get_articles( list => 'featured' ) },
        'watch_list-count' => int @{ $self->{model}->get_articles( list => 'watch_list' ) },
        'inbox-count'      => int @{ $self->{model}->get_articles( list => 'inbox' ) },

        # random articles...
        'random_articles' => $self->{model}->get_articles( list => 'watch_list', random_articles => 5 ),

        # page articles...
        'watch_list' => $self->{model}->get_articles( list => 'watch_list' ),

        # page title...
        'page_title' => 'Viewing... \'Watch List\'',
    };

    # now send data to the client...
    $self->ht_param(@page_data);

}

# page handler for 'inbox' page requests...
sub PH_inbox {

    # preamble...
    my ($self) = @_;

    # build page content...
    my @page_data = {

        # section statistics...
        'featured-count'   => int @{ $self->{model}->get_articles( list => 'featured' ) },
        'watch_list-count' => int @{ $self->{model}->get_articles( list => 'watch_list' ) },
        'inbox-count'      => int @{ $self->{model}->get_articles( list => 'inbox' ) },

        # random articles...
        'random_articles' => $self->{model}->get_articles( list => 'watch_list', random_articles => 5 ),

        # page articles...
        'inbox' => $self->{model}->get_articles( list => 'inbox' ),

        # page title...
        'page_title' => 'Viewing... \'Inbox\'',
    };

    # now send data to the client...
    $self->ht_param(@page_data);

}

# b e g i n ::: 'clean up' phase...

# handler for cleaning up after the response phase has finished...
sub OH_cleanup {

    # preamble...
    my ($self) = @_;

    # here is the magic of tvs.  the following methods will
    # essentially automate the news portal...

    $self->{model}->get_feeds(); # update feeds/articles...
    $self->{model}->do_prune();  # remove old and un-interesting articles and comments...
    $self->{model}->do_rss();    # update tvs RSS subscription file...

    # shutdown the instance...
    $self->{model}->do_shutdown();

}

# end of class...
1;
