// view.js - TVS auto-syndicated news portal...

/* this functional library is currently in the process of being ported
   to an object-oriented class for a smoother integration to the
   tvs news portal back-end. */

// class constructor...
function View () {

    // public method containers...
    this.articles = {};     // articles container...
    this.effects  = {};     // effects container...
    this.external = {};     // external functions...

    // What was once the old 'clean-up' phase of Controller.pm
    // has now been moved here. I'll work to make this even nicer,
    // but so far this is a major performance enhancement to the page load time.
    // The previous method wasn't asynchronus.

    //new Ajax.Request( '/model', { parameters: 'do_prune=1&do_rss=1&get_feeds=1' } );


/* c l a s s _ m e t h o d s */

// method to determine if the client can request a vote...
this.articles.set_voting = function ( name, tbl_id, id ) {

    // first check to see if the correct number of arguments has been passed...
    if ( this.set_voting.arguments.length !=3 ) { return; }

    // next we check to see if the user has already voted on this article...
    var cookies = document.cookie;
    var article = cookies.indexOf( id + '=' );

    // if the article has been voted on, do nothing.  otherwise provide
    // them an option to vote via the view.articles.do_vote method...
    if ( article != -1 ) {

        /* do nothing */
    }
    else {

        // provide the option to submit a vote...
        document.write( '<a style="margin-right: 2px;" href="javascript:view.articles.do_vote( \'' + name + ':' + tbl_id + '\', \'' + id + '\' );\">Vote on Article</a>' );
    }

    // and return...
    return;

}

// function to send voting information...
this.articles.do_vote = function ( params, id ) {

    // first check to see if the correct number of arguments has been passed...
    if ( this.do_vote.arguments.length !=2 ) { return }

    // send http request to TVS for voting...
    new Ajax.Request( '/vote', { parameters: params } );

    // create a cookie to store voted on article information...
    set_cookie( id );

    new Effect.Puff( 'article-' + id );

    return;

}

/* h e l p e r _ f u n c t i o n s */

// internal function used to send cookie data to clients...
function set_cookie ( id ) {

    // set date/time for cookie expiration ( 24hours )...
    var date = new Date();
    date.setTime( date.getTime() + ( 60 * 60 * 60 * 24 ) );

    // set the cookie information for the voted on article...
    document.cookie = id + '=voted;' + ';' + 'path=/; ' + 'domain=' + location.hostname + ';' + 'expires=' + date.toGMTString() + ';';

    // and return...
    return;

}

// end of class...
}


/* the remaining functional portion of this library */

// function to handle the scrolling of article pages...
function scroll_to ( position ) {

    // scroll to position...
    new Effect.ScrollTo( position );

}

// function to handle the display of external links...
function external_links () {

/* a great work-around developed by kpavery to avoid
   using the xhtml 'target' element.  this workaround
   gives the same effect while maintaining strict
   xhtml compliance. */

    // if the client browser doesn't support js 1.5...
    if ( !document.getElementsByTagName ) { return; }

    // otherwise assign values to create the external link object...
    var anchors = document.getElementsByTagName( "a" );
    for ( var i = 0; i < anchors.length; i++ ) {
        var anchor = anchors[i];

        if ( anchor.getAttribute("href") && anchor.getAttribute("rel") == "external" ) {
             anchor.target = "_blank";
        }
    }
}

// onload event handlers...
window.onload = external_links;

// end of library...
