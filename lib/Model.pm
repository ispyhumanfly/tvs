# Model.pm :: The TVS News Engine

use Modern::Perl;
package Model;

sub new {

    use LWP::Simple qw/ get /;
    use Digest::MD5 qw/ md5_hex /;
    use DateTime::Format::MySQL;
    use XML::Simple;
    use XML::RSS::Feed;
    use HTML::Strip;
    use DBI;

    my ($class, %arguments) = @_;

    $arguments{config}   = new XML::Simple->XMLin('config/config.xml');
    $arguments{feeds}    = new XML::Simple->XMLin('config/feeds.xml');
    $arguments{language} = new XML::Simple->XMLin('config/language.xml');
    $arguments{disqus}   = new XML::Simple->XMLin('config/disqus.xml');

    my $db_database = $arguments{config}->{mysql}->{database};
    my $db_host     = $arguments{config}->{mysql}->{host};
    my $db_user     = $arguments{config}->{mysql}->{user};
    my $db_password = $arguments{config}->{mysql}->{password};

    $arguments{mysql} = DBI->connect("DBI:mysql:database=$db_database:host=",
        $db_user, $db_password, {'PrintError' => 0, 'RaiseError' => 1});

    $arguments{mysql}->{'mysql_auto_reconnect'} = 1;
    $arguments{mysql}->{'mysql_enable_utf8'}    = 1;

    return bless \%arguments, $class;

}

sub get_articles {

    my ($self, %arguments) = @_;
    return 1 unless exists $arguments{list};

    my (@articles);

    my $index = 0;
    
    for (@{$self->{feeds}->{feed}}) {
        if ($self->{feeds}->{feed}->[$index]->{title}) {

            my $feed = $self->{feeds}->{feed}->[$index]->{title};

            unless (
                do_tables(
                    $self,
                    table_exists => $feed,
                    type         => 'articles'
                )
              )
            {
                do_tables(
                    $self,
                    create_table => $feed,
                    type         => 'articles'
                );
            }

            my $statement;

            if ($arguments{list} eq 'home') {

                my $query =
                    "SELECT * FROM articles_$feed "
                  . "WHERE votes >= $self->{config}->{persona}->{home}->{votes} "
                  . "AND DATE_SUB(CURDATE(),INTERVAL $self->{config}->{persona}->{home}->{days} day) <= date";

                $statement = $self->{mysql}->prepare($query);
                $statement->execute();
            }

            elsif ($arguments{list} eq 'featured') {

                my $query =
                    "SELECT * FROM articles_$feed WHERE votes "
                  . "BETWEEN $self->{config}->{persona}->{featured}->{votes} "
                  . "AND $self->{config}->{persona}->{home}->{votes} "
                  . "AND DATE_SUB(CURDATE(),INTERVAL $self->{config}->{persona}->{featured}->{days} day) <= date";

                $statement = $self->{mysql}->prepare($query);
                $statement->execute();
            }

            elsif ($arguments{list} eq 'watch_list') {

                my $query =
                    "SELECT * FROM articles_$feed WHERE votes "
                  . "BETWEEN $self->{config}->{persona}->{watch_list}->{votes} "
                  . "AND $self->{config}->{persona}->{featured}->{votes} "
                  . "AND DATE_SUB(CURDATE(),INTERVAL $self->{config}->{persona}->{watch_list}->{days} day) <= date";

                $statement = $self->{mysql}->prepare($query);
                $statement->execute();
            }

            elsif ($arguments{list} eq 'inbox') {

                my $query =
                    "SELECT * FROM articles_$feed WHERE votes "
                  . "BETWEEN $self->{config}->{persona}->{inbox}->{votes} "
                  . "AND $self->{config}->{persona}->{watch_list}->{votes} "
                  . "AND DATE_SUB(CURDATE(),INTERVAL $self->{config}->{persona}->{inbox}->{days} day) <= date";

                $statement = $self->{mysql}->prepare($query);
                $statement->execute();
            }

            elsif ($arguments{list} eq 'all') {

                my $query = "SELECT * FROM articles_$feed";

                $statement = $self->{mysql}->prepare($query);
                $statement->execute();
            }

            while (my $ref = $statement->fetchrow_hashref()) {

                my $struct = {
                    name   => $feed,
                    id     => $feed . $ref->{id},
                    tbl_id => $ref->{id},
                    title  => $ref->{title},
                    info   => $ref->{info},
                    url    => $ref->{url},
                    icon   => $ref->{icon},
                    votes  => $ref->{votes},
                    date   => $ref->{date},
                    md5    => $ref->{md5},
                };

                push @articles, $struct;
            }

            $index++;
        }
    }

    @articles = do_random($self, @articles);

    if (exists $arguments{filter_by_period}) {
        @articles = _filter_by_period(
            articles => \@articles,
            period   => $arguments{filter_by_period}
        );
    }

    return \@articles;

}

sub _filter_by_period {

    my %arguments = @_;
    return 1 unless exists $arguments{articles} and $arguments{period};

    my @filtered_articles;

    for (@{$arguments{articles}}) {

        if ($arguments{period} eq 'today') {

            my $article_date =
              DateTime::Format::MySQL->parse_date($_->{date});
            my $today_date = DateTime->now;

            next if $article_date->day_of_year != $today_date->day_of_year;
            push @filtered_articles, $_;

        }
        elsif ($arguments{period} eq 'week') {

            my $article_date =
              DateTime::Format::MySQL->parse_date($_->{date});
            my $week_date = DateTime->now->subtract(days => 7);

            next if $article_date->day_of_year <= $week_date->day_of_year;
            push @filtered_articles, $_;

        }
        elsif ($arguments{period} eq 'month') {

            my $article_date =
              DateTime::Format::MySQL->parse_date($_->{date});
            my $month_date = DateTime->now->subtract(days => 30);

            next if $article_date->day_of_year <= $month_date->day_of_year;
            push @filtered_articles, $_;

        }
        elsif ($arguments{period} eq 'quarter') {

            my $article_date =
              DateTime::Format::MySQL->parse_date($_->{date});
            my $quarter_date = DateTime->now->subtract(days => 90);

            next if $article_date->day_of_year <= $quarter_date->day_of_year;
            push @filtered_articles, $_;

        }
        elsif ($arguments{period} eq 'year') {

            my $article_date =
              DateTime::Format::MySQL->parse_date($_->{date});
            my $year_date = DateTime->now->subtract(days => 365);

            next if $article_date->day_of_year <= $year_date->day_of_year;
            push @filtered_articles, $_;

        }
        elsif ($arguments{period} eq 'decade') {

            my $article_date =
              DateTime::Format::MySQL->parse_date($_->{date});
            my $decade_date = DateTime->now->subtract(days => 3650);

            next if $article_date->day_of_year <= $decade_date->day_of_year;
            push @filtered_articles, $_;

        }
    }

    return \@filtered_articles;
}

sub get_article {

    my ($self, %arguments) = @_;
    my (@articles, $statement);

    if (($arguments{'feed'}) and ($arguments{'id'})) {

        my $feed = $arguments{feed};
        my $id   = $arguments{id};

        $statement =
          $self->{mysql}
          ->prepare("SELECT * FROM articles_$feed WHERE id = $id");
        $statement->execute();

        while (my $result = $statement->fetchrow_hashref()) {

            my $entry = {
                name   => $feed,
                id     => $feed . $result->{id},
                tbl_id => $result->{id},
                title  => $result->{title},
                info   => $result->{info},
                url    => $result->{url},
                icon   => $result->{icon},
                votes  => $result->{votes},
                date   => $result->{date},
                md5    => $result->{md5},
            };

            push @articles, $entry;
        }
    }

    return \@articles;

}

# method to handle the retrieval, prepartion
# and insertion into database of the current
# feeds.xml RSS list...
sub get_feeds {

    # preamble...
    my $self = shift;
    my (@list, @md5_list, %info, $md5_exists);

    # obtain values for XML::RSS::Feed instance...
    # and generate a feed list from feeds.xml...
    my $max = scalar @{$self->{feeds}->{feed}};
    for (my $i = 0; $i <= $max; $i++) {
        if ($self->{feeds}->{feed}->[$i]->{title}) {

            # required XML::RSS::Feed values...
            my $struct = {
                url   => $self->{feeds}->{feed}->[$i]->{url},
                name  => $self->{feeds}->{feed}->[$i]->{title},
                debug => 1,
            };
            push @list, $struct;

            # additional information required for database entries...
            $info{$self->{feeds}->{feed}->[$i]->{title}} =
              "$self->{feeds}->{feed}->[$i]->{icon}";
        }
    }

    # here, we select a feed at random and check for a new headline...
    my $feed = new XML::RSS::Feed(%{$list[int rand($#list + 1)]});
    $feed->parse(get($feed->url));

    # cycle through all new headlines...
    for my $headline ($feed->late_breaking_news) {

        # assign scalar values to headline information...
        my $name  = do_clean($self, string => '' . $feed->name . '');
        my $title = do_clean($self, string => '' . $headline->headline . '');
        my $url   = do_clean($self, string => '' . $headline->url . '');
        my $info =
          do_clean($self, string => '' . $headline->description . '');
        my $icon = do_clean($self, string => $info{$name});
        my $md5 = md5_hex($url);

        # first i use Digest::MD5 to check the incoming url against
        # any pre-existing ones. this was the most effecient way i
        # could find to make sure the article wouldn't be duplicated...
        my $sth = $self->{mysql}->prepare("SELECT * FROM articles_$name");
        $sth->execute();

        # extract data from each entry...
        while (my $ref = $sth->fetchrow_hashref()) {

            # check existing md5 checksums, and append to a list...
            my $struct = {md5 => $ref->{'md5'}};
            push @md5_list, $struct;
        }

        # check the inbound md5 checksum against any pre-existing ones...
        for my $value (@md5_list) {
            if ($md5 eq $value->{md5}) { $md5_exists = 1; }
        }

        # unless the feed recieved already matches a feed inside the
        # database, insert new article into database...
        unless ($md5_exists) {

            # insert article values into database...
            $self->{mysql}->do(
                "INSERT INTO articles_$name ( title, url, info, icon, md5, votes, date ) VALUES ( "
                  . $self->{mysql}->quote($title) . ",
                               "
                  . $self->{mysql}->quote($url) . ", "
                  . $self->{mysql}->quote($info) . ", "
                  . $self->{mysql}->quote($icon) . ",
                               "
                  . $self->{mysql}->quote($md5) . ", 0, CURDATE()) "
            );
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
    my $rss = new XML::RSS(version => '2.0');
    $rss->channel(
        title       => $self->{config}->{rss}->{title},
        link        => $self->{config}->{rss}->{link},
        language    => $self->{config}->{rss}->{language},
        description => $self->{config}->{rss}->{description},
        rating      => $self->{config}->{rss}->{rating},
        copyright   => $self->{config}->{rss}->{copyright},
        webMaster   => $self->{config}->{rss}->{webmaster},
    );

    # next we load all of the current 'featured' articles into an
    # array ref, and append them to the RSS file...
    my $articles = get_articles($self, list => 'featured');
    for my $article (@{$articles}) {
        $rss->add_item(
            title       => '[Featured Article] ' . $article->{title},
            permaLink   => $article->{url},
            enclosure   => {url => $article->{url}, type => 'text/plain'},
            description => $article->{info},
        );
    }

    # now save the freshly generated rss feed...
    eval { $rss->save('public/site_feed.rss') };
    if   ($@) { return 0 }
    else      { return 1 }

}

# method to weed out old/un-voted on articles...
sub do_prune {

    # preamble...
    my ($self, %arguments) = @_;
    my (@list, $sth);

    # generate a feed list from feeds.xml...
    my $max = @{$self->{feeds}->{feed}};
    for (my $i = 0; $i <= $max; $i++) {
        if ($self->{feeds}->{feed}->[$i]->{title}) {

            # snag feed names from feeds.xml...
            my $name = $self->{feeds}->{feed}->[$i]->{title};
            push @list, $name;
        }
    }

    # select a feed at random for article pruning and
    # then begin the pruning process...
    my $feed = $list[int rand($#list + 1)];

    # if the voting option in config.xml is a number,
    # only prune articles with X ammount of votes...
    if ($self->{config}->{prune}->{votes} =~ /[0-9]/x) {
        $sth =
          $self->{mysql}->prepare(
            "DELETE FROM articles_$feed WHERE votes = $self->{config}->{prune}->{votes} AND DATE_SUB(CURDATE(),INTERVAL $self->{config}->{prune}->{days} day) >= date"
          );
    }

    # if no voting value given in config.xml, assume that all old
    # articles are to be pruned...
    if (   ($self->{config}->{prune}->{votes} eq 'all')
        or ($self->{config}->{prune}->{votes} eq ''))
    {
        $sth =
          $self->{mysql}->prepare(
            "DELETE FROM articles_$feed WHERE DATE_SUB(CURDATE(),INTERVAL $self->{config}->{prune}->{days} day) >= date"
          );
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
    my ($self, @arguments) = @_;

    # initial randomization values...
    my @array = @arguments;
    my $i     = $#array;
    my $j;

    # loop through every element...
    for my $item (@array) {

        # randomize...
        --$i;
        $j = int rand($i + 1);
        next if $i == $j;
        @array[$i, $j] = @array[$j, $i];
    }
    return @array;

}

# method to build tables for feeds.  this is also
# used to check the existance or status of existing tables...
sub do_tables {

    # preamble...
    my ($self, %arguments) = @_;

    # if the 'table_exists' argument passed...
    if ($arguments{table_exists}) {

        # if we are checking an article entry...
        if ($arguments{type} eq 'articles') {

            # evaluate if the feed already exists as a table...
            eval {
                $self->{mysql}->do(
                    "SELECT * FROM articles_$arguments{table_exists} WHERE 1 = 0"
                );
            };
            if   ($@) { return 0; }
            else      { return 1; }
        }
    }

    # if the 'create_table' argument is passed...
    if ($arguments{create_table}) {

        # if we are creating a new article entry...
        if ($arguments{type} eq 'articles') {

            # insert the new article into the database...
            eval {
                $self->{mysql}->do(
                    "CREATE TABLE articles_$arguments{create_table}
                    (id INT NOT NULL AUTO_INCREMENT, PRIMARY KEY(id),
                    title VARCHAR(1000) NOT NULL, url VARCHAR(5000),
                    info VARCHAR(5000), icon VARCHAR(50),
                    md5 VARCHAR(32), votes INT, date DATE)"
                );
            };
            if   ($@) { return 0; }
            else      { return 1; }
        }
    }
    return;

}

# method to clean and encode xhtml strings. future
# revisions to this method will contain parameters for
# parsing xhtml in differant ways...
sub do_clean {

    # preamble...
    my ($self, %arguments) = @_;

    # initiate HTML::Strip instance, and strip all html
    # codes from the string. Since HTML::Entities should
    # also be installed; the remaining string should be
    # properly encoded for XHTML standards.
    my $strip = new HTML::Strip;
    my $clean = $strip->parse($arguments{string});

    return $clean;

}

# method to update 'vote' values for articles. tvs
# currently relies on client-side scripting from view.js, the
# tvs front-end class as well as cookies...
sub do_vote {

    # preamble...
    my ($self, %arguments) = @_;

    my $feed = $arguments{name};
    my $id   = $arguments{tbl_id};

    # add user vote to table data...
    $self->{mysql}
      ->do("UPDATE articles_$feed SET votes=votes+1 WHERE id=$id");
    return;

}

# method to shutdown the tvs engine...
sub do_shutdown {

    # preamble...
    my ($self, %arguments) = @_;

    # clost out the DBI connection...
    $self->{mysql}->disconnect();

    # remove instance from memory...
    $self = ();
    return;

}

# end of class...
1;