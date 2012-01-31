package Objective::New::Omegle;

use HTTP::Async;
use HTTP::Request::Common;
use LWP::UserAgent;
use JSON;

our $VERSION    = '0.1';
my  @servers    = qw[bajor.omegle.com cardassia.omegle.com promenade.omegle.com quarks.omegle.com 97.107.132.144];
my  $lastserver = 2;

interface {

    pub meth qw(start go say type stoptype disconnect);
    prv meth qw(request_next_event get_next_events handle_events handle_event newserver);
    pub attr qw(typing);
    prv attr qw(json useragent async callbacks);

}

implementation {

    # constructor method

    construct {
        my %callbacks = @_;
        ( callbacks \%callbacks           );
        ( async     new HTTP::Async       );
        ( useragent new LWP::UserAgent    );
        ( json      new JSON              );
        ( server    'http://'.newserver() );
        ( typing    0                     );
    }

    ####################
    # INSTANCE METHODS #
    ####################

    # start

    method {
        my $res = (useragent)->post((server).'/post');
        my $id  = $res->content || '';
        $id =~ s/"//g;
        return unless $id;
        ( id $id );
        request_next_event();
        return $id
    }

    # go
    method {
	    foreach my $res (get_next_events()) {
	        next unless $res;
            handle_events($res->content);
        }
        request_next_event();
    }

    # say
    method {
        my $msg = shift;
        return unless id;
        (async)->add(POST (server).'/send', [ id => id, msg => $msg ]);
    }

    # type
    method {
        return unless id;
        (async)->add(POST (server).'/typing', [ id => id ])
    }

    # stoptype
    method {
        return unless id;
        (async)->add(POST (server).'/stoptyping', [ id => id ])
    }

    # disconnect
    method {
        return unless id;
        (async)->add(POST (server).'/disconnect', [ id => id ])
    }

    #################
    # CLASS METHODS #
    #################

    # request_next_event
    method {
        return unless id;
        (async)->add(POST (server).'/events', [ id => id ])
    }

    # get_next_events
    method {
        my @f = ();
        while (my $res = (async)->next_response) {
            push @f, $res
        }
        return @f
    }

    # handle_events
    method {
        my $json = shift;
        return unless $json =~ m/^\[/;
        my $events = (json)->decode($json);
        handle_event(@$_) foreach @$events;
    }

    # handle_event
    method {
        my @event = @_;
        given ($event[0]) {

        when ('connected') {
            callback('on_connect');
        }

        when ('gotMessage') {
            callback('on_chat', $event[1]);
            ( typing 0 );
        }

        when ('strangerDisconnected') {
            callback('on_disconnect');
            ( id undef );
        }

        when ('typing') {
            callback('on_type') unless typing;
            ( typing 1 );
        }

        when ('stoppedTyping') {
            callback('on_stoptype') if typing;
            ( typing 0 );
        }

        }
        return 1
    }

    # callback
    method {
        my $callback  = shift;
        my %callbacks = %{+callbacks};
        if (exists $callbacks{$callback}) {
            my $call = $callbacks{$callback};
            return $call->(SELF, @_);
        }
        return
    }

    # newserver
    method {
        if ($lastserver == $#servers) {
            $lastserver = 0;
            return $servers[0]
        }
        return $servers[++$lastserver]
    }

}
