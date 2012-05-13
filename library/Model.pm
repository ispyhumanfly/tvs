# Model.pm - TVS auto-syndicated news portal...

package Model;

use warnings;
use strict;

# class contsructor...
sub new {

    # required CPAN modules...
    use LWP::Simple qw/ get /;
    use Digest::MD5 qw/ md5_hex /;
    use XML::RSS::Feed;
    use HTML::Strip;
    use XML::Simple;
    use DBI;

    # preamble...
    my ( $class, %arguments ) = @_;

    # pre-load instance wide configuration files...
    $arguments{config} = new XML::Simple->XMLin('config/config.xml');
    $arguments{feeds}  = new XML::Simple->XMLin('config/feeds.xml');

    # initiate DBI connection...
    $arguments{dbase} = DBI->connect( "$arguments{config}->{dbase}->{driver}:database=$arguments{config}->{dbase}->{database}:host=$arguments{config}->{dbase}->{host}",
                                       $arguments{config}->{dbase}->{user}, $arguments{config}->{dbase}->{password},
                                       { 'PrintError' => 0, 'RaiseError' => 1 } );
	$arguments{dbase}->{'mysql_enable_utf8'} = 1;

    # and bless the OO goodness :)
    return bless \%arguments, $class;

}

# method to prepare, sort and return the current
# articles stored within the database...
sub get_articles {

    # preamble...
    my ( $self, %arguments ) = @_;
    my ( @articles, $sth );

    # sort and return articles...
    my $max = @{ $self->{feeds}->{feed} };
    for ( my $i = 0; $i <= $max; $i++ ) {
        if ( $self->{feeds}->{feed}->[$i]->{title} ) {

            # first step is to check and see if the feed table associated
            # with this feeds.xml entry even exists within the database...
            if ( do_tables( $self, table_exists => $self->{feeds}->{feed}->[$i]->{title}, type => 'articles' ) ) {

                # do nothing, the feed already exists in the database...
            }
            else {

                # create the table, and prepare for later use...
                do_tables( $self, create_table => $self->{feeds}->{feed}->[$i]->{title}, type => 'articles' );
            }

            # retrieve articles for the featured & home section ( ie. articles
            # that have been voted on more than 2 times...
            if ( ( $arguments{'list'} eq 'featured' ) or ( $arguments{list} eq 'home' ) ) {

                # retrieve table data...
                $sth = $self->{dbase}->prepare("SELECT * FROM articles_$self->{feeds}->{feed}->[$i]->{title} WHERE votes >= $self->{config}->{interval}->{featured}->{votes} AND DATE_SUB(CURDATE(),INTERVAL $self->{config}->{interval}->{featured}->{days} day) <= date");
                $sth->execute();
            }

            # retrieve articles for the watch_list section ( ie.
            # articles that have been voted on atleast once.
            if ( $arguments{'list'} eq 'watch_list' ) {

                # retrieve table data...
                $sth = $self->{dbase}->prepare("SELECT * FROM articles_$self->{feeds}->{feed}->[$i]->{title} WHERE votes BETWEEN $self->{config}->{interval}->{watch_list}->{votes} AND $self->{config}->{interval}->{featured}->{votes}-1 AND DATE_SUB(CURDATE(),INTERVAL $self->{config}->{interval}->{watch_list}->{days} day) <= date");
                $sth->execute();
            }

            # retrieve articles for the inbox section ( ie. articles that
            # have yet to be voted on...
            if ( $arguments{'list'} eq 'inbox' ) {

                # retrieve table data...
                $sth = $self->{dbase}->prepare("SELECT * FROM articles_$self->{feeds}->{feed}->[$i]->{title} WHERE votes = $self->{config}->{interval}->{inbox}->{votes} AND DATE_SUB(CURDATE(),INTERVAL $self->{config}->{interval}->{inbox}->{days} day) <= date");
                $sth->execute();
            }

            # extract data from each entry...
            while ( my $ref = $sth->fetchrow_hashref() ) {

                my $struct = {
                    name   => $self->{feeds}->{feed}->[$i]->{title},
                    id     => $self->{feeds}->{feed}->[$i]->{title} . $ref->{id},
                    tbl_id => $ref->{id},
                    title => $ref->{title},
                    info  => $ref->{info},
                    url   => $ref->{url},
                    icon  => $ref->{icon},
                    votes => $ref->{votes},
                    date  => $ref->{date},
                    md5   => $ref->{md5},
                };

                push @articles, $struct;
            }
        }
    }

    # randomize all articles... i do this so as to keep the
    # appearance of fresh looking content... fooled yuh :)
    @articles = do_random( $self, @articles );

    # if this is a 'home' page article request, we handle
    # things differantly than for the other pages...
    if ( $arguments{list} eq 'home' ) { @articles = $articles[int rand $#articles]; }

    # if the 'random_articles' argument is passed, shorten the length
    # of the articles listed for better viewing/usage...
    if ( $arguments{random_articles} ) { @articles = @articles[ 0 .. $arguments{random_articles} ] }

    # and return...
    return \@articles;

}

# method to handle the retrieval, prepartion
# and insertion into database of the current
# feeds.xml RSS list...
sub get_feeds {

    # preamble...
    my $self = shift;
    my ( @list, @md5_list, %info, $md5_exists );

    # obtain values for XML::RSS::Feed instance...
    # and generate a feed list from feeds.xml...
    my $max = scalar @{ $self->{feeds}->{feed} };
    for ( my $i = 0; $i <= $max; $i++ ) {
        if ( $self->{feeds}->{feed}->[$i]->{title} ) {

            # required XML::RSS::Feed values...
            my $struct = {
                url   => $self->{feeds}->{feed}->[$i]->{url},
                name  => $self->{feeds}->{feed}->[$i]->{title},
                debug => 1,
            };
            push @list, $struct;

            # additional information required for database entries...
            $info{ $self->{feeds}->{feed}->[$i]->{title} } = "$self->{feeds}->{feed}->[$i]->{icon}";
        }
    }

    # here, we select a feed at random and check for a new headline...
    my $feed = new XML::RSS::Feed( %{ $list[ int rand($#list) ] } );
    $feed->parse( get( $feed->url ) );

    # cycle through all new headlines...
    for my $headline ( $feed->late_breaking_news ) {

        # assign scalar values to headline information...
        my $name  = do_clean( $self, string => '' . $feed->name . '' );
        my $title = do_clean( $self, string => '' . $headline->headline . '' );
        my $url   = do_clean( $self, string => '' . $headline->url . '' );
        my $info  = do_clean( $self, string => '' . $headline->description . '' );
        my $icon  = do_clean( $self, string => $info{$name} );
        my $md5   = md5_hex($url);

        # first i use Digest::MD5 to check the incoming url against any pre-existing ones.
        # this was the most effecient way i could find to make sure the article wouldn't be duplicated...
        my $sth = $self->{dbase}->prepare("SELECT * FROM articles_$name");
        $sth->execute();

        # extract data from each entry...
        while ( my $ref = $sth->fetchrow_hashref() ) {

            # check existing md5 checksums, and append to a list...
            my $struct = { md5 => $ref->{'md5'} };
            push @md5_list, $struct;
        }

        # check the inbound md5 checksum against any pre-existing ones...
        for my $value (@md5_list) {
            if ( $md5 eq $value->{md5} ) { $md5_exists = 1; }
        }

        # unless the feed recieved already matches a feed inside the
        # database, insert new article into database...
        unless ($md5_exists) {

            # insert article values into database...
            $self->{dbase}->do( "INSERT INTO articles_$name ( title, url, info, icon, md5, votes, date ) VALUES ( " . $self->{dbase}->quote($title) . ",
                               " . $self->{dbase}->quote($url) . ", " . $self->{dbase}->quote($info) . ", " . $self->{dbase}->quote($icon) . ",
                               " . $self->{dbase}->quote($md5) . ", 0, CURDATE()) " );
        }
    }
    return;

}

# method to create a new RSS feed based on the
# current contents of the 'featured' articles listing...
sub do_rss {

    # preamble...
    my $self = shift;

    # initiate XML::RSS instance and append channel data...
    my $rss = new XML::RSS ( version => '2.0');
    $rss->channel( title       => $self->{config}->{rss}->{title},
                   link        => $self->{config}->{rss}->{link},
                   language    => $self->{config}->{rss}->{language},
                   description => $self->{config}->{rss}->{description},
                   rating      => $self->{config}->{rss}->{rating},
                   copyright   => $self->{config}->{rss}->{copyright},
                   webMaster   => $self->{config}->{rss}->{webmaster},
                );

    # next we load all of the current 'featured' articles into an
    # array ref, and append them to the RSS file...
    my $articles = get_articles( $self, list => 'featured' );
    for my $article ( @ { $articles } ) {
        $rss->add_item( title       => '[Featured Article] ' . $article->{title},
                        permaLink   => $article->{url},
                        enclosure   => { url => $article->{url}, type => 'text/plain' },
                        description => $article->{info},
                    );
    }

    # now save the freshly generated rss feed...
    eval { $rss->save( 'public/site_feed.rss' ) };
    if ( $@ ) { return 0 } else { return 1 }

}

# method to weed out old/un-voted on articles...
sub do_prune {

    # preamble...
    my ( $self, %arguments ) = @_;
    my ( @list, $sth );

    # generate a feed list from feeds.xml...
    my $max = @{ $self->{feeds}->{feed} };
    for ( my $i = 0; $i <= $max; $i++ ) {
        if ( $self->{feeds}->{feed}->[$i]->{title} ) {

            # snag feed names from feeds.xml...
            my $name = $self->{feeds}->{feed}->[$i]->{title};
            push @list, $name;
        }
    }

    # select a feed at random for article pruning and
    # then begin the pruning process...
    my $feed = $list[ int rand($#list) ];

    # if the voting option in config.xml is a number,
    # only prune articles with X ammount of votes...
    if ( $self->{config}->{prune}->{votes} =~ /[0-9]/x ) {
        $sth = $self->{dbase}->prepare("DELETE FROM articles_$feed WHERE votes = $self->{config}->{prune}->{votes} AND DATE_SUB(CURDATE(),INTERVAL $self->{config}->{prune}->{days} day) >= date");
    }

    # if no voting value given in config.xml, assume that all old
    # articles are to be pruned...
    if ( ( $self->{config}->{prune}->{votes} eq 'all' ) or ( $self->{config}->{prune}->{votes} eq '' ) ) {
        $sth = $self->{dbase}->prepare("DELETE FROM articles_$feed WHERE DATE_SUB(CURDATE(),INTERVAL $self->{config}->{prune}->{days} day) >= date");
    }

    # execute the SQL statement, and return...
    $sth->execute();
    return;

}

# method to randomize arrays, mostly article listings.
# this method is largely based on an 'array shuffler' example
# from the perl cookbook...
sub do_random {

    # preamble...
    my ( $self, @arguments ) = @_;

    # initial randomization values...
    my @array = @arguments;
    my $i     = $#array;
    my $j;

    # loop through every element...
    for my $item (@array) {

        # randomize...
        --$i;
        $j = int rand( $i + 1 );
        next if $i == $j;
        @array[ $i, $j ] = @array[ $j, $i ];
    }
    return @array;

}

# method to build tables for feeds / comments.  this is also
# used to check the existance or status of existing tables...
sub do_tables {

    # preamble...
    my ( $self, %arguments ) = @_;

    # if the 'table_exists' argument passed...
    if ( $arguments{table_exists} ) {

        # if we are checking an article entry...
        if ( $arguments{type} eq 'articles' ) {

            # evaluate if the feed already exists as a table...
            eval { $self->{dbase}->do("SELECT * FROM articles_$arguments{table_exists} WHERE 1 = 0") };
            if ( $@ ) { return 0; } else { return 1; }
        }
    }

    # if the 'create_table' argument is passed...
    if ( $arguments{create_table} ) {

        # if we are creating a new article entry...
        if ( $arguments{type} eq 'articles' ) {

            # insert the new article into the database...
            eval { $self->{dbase}->do(
                    "CREATE TABLE articles_$arguments{create_table}
                    (id INT NOT NULL AUTO_INCREMENT, PRIMARY KEY(id), title VARCHAR(1000) NOT NULL, url VARCHAR(5000), info VARCHAR(5000), icon VARCHAR(50), md5 VARCHAR(32), votes INT, date DATE)"
                ) };
            if ( $@ ) { return 0; } else { return 1; }
        }
    }
    return;

}

# method to clean and encode xhtml strings. future
# revisions to this method will contain parameters for
# parsing xhtml in differant ways...
sub do_clean {

    # preamble...
    my ( $self, %arguments ) = @_;

    # initiate HTML::Strip instance, and strip all html
    # codes from the string. Since HTML::Entities should
    # also be installed; the remaining string should be
    # properly encoded for XHTML standards.
    my $strip = new HTML::Strip;
    my $clean = $strip->parse( $arguments{string} );

    return $clean;

}

# method to update 'vote' values for articles. tvs
# currently relies on client-side scripting from view.js, the
# tvs front-end class as well as cookies...
sub do_vote {

    # preamble...
    my ( $self, %arguments ) = @_;

    # add user vote to table data...
    $self->{dbase}->do("UPDATE articles_$arguments{name} SET votes=votes+1 WHERE id=$arguments{tbl_id}");
    return;

}

# method to shutdown the tvs engine...
sub do_shutdown {

    # preamble...
    my ( $self, %arguments ) = @_;

    # clost out the DBI connection...
    $self->{dbase}->disconnect();

    # remove instance from memory...
    $self = ();
    return;

}

# end of class...
1;
