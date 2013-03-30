// view.js - TVS auto-syndicated news portal...

function View () {

    this.articles = {};     // articles container...
    this.effects  = {};     // effects container...
    this.external = {};     // external functions...

    // load scriptaculous back-end...
    //var scripts = ('');
    //
    //var script = document.createElement('script');
    //script.type = 'text/javascript';
    //script.src = libraryName;
    //document.getElementsByTagName('head')[0].appendChild(script);
      
    //new Ajax.Request( '/model', { parameters: 'do_prune=1&do_rss=1&get_feeds=1' } );


this.articles.set_voting = function ( name, tbl_id, id ) {

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
        document.write( '<a style="margin-right: 2px;" href="javascript:view.articles.do_vote( \'' + name + ':' + tbl_id + '\', \'' + id + '\' );\">Like Article</a>' );
    }

    // and return...
    return;

}

this.articles.set_voting = function ( name, tbl_id, id ) {

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
        document.write( '<a style="margin-right: 2px;" href="javascript:view.articles.do_vote( \'' + name + ':' + tbl_id + '\', \'' + id + '\' );\">Like Article</a>' );
    }

    // and return...
    return;

}
this.articles.do_vote = function ( params, id ) {

    if ( this.do_vote.arguments.length !=2 ) { return }

    // send http request to TVS for voting...
    new Ajax.Request( '/vote', { parameters: params } );

    // create a cookie to store voted on article information...
    set_cookie( id );

    new Effect.Pulsate( 'article-' + id );

    return;

}

this.articles.do_vote_puff = function ( params, id ) {

    if ( this.do_vote.arguments.length !=2 ) { return }

    // send http request to TVS for voting...
    new Ajax.Request( '/vote', { parameters: params } );

    // create a cookie to store voted on article information...
    set_cookie( id );

    new Effect.Puff( 'article-' + id );

    return;

}

this.effects.smooth_redirect = function (name, id) {
    
    new Effect.DropOut('article-' + id);
    setTimeout(3000);
    new Effect.Fold('main_page');
    
    //window.location = '/' + name + '/' + id;
    
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
