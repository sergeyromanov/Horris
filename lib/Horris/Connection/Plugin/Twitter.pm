package Horris::Connection::Plugin::Twitter;
# ABSTRACT: Twitter Plugin on Horris

=head1 SYNOPSIS

    # assume here at a irc channel
    HH:MM:SS    NICK | http://twitter.com/#!/umma_coding_bot/status/8721128864350209
    HH:MM:SS BOTNAME | 엄마코딩봇: 세계가 네 코드를 지켜보고 있단다. 버그 배출을 자제하렴.

=head1 DESCRIPTION

When bot got a twitter url, Notice the title.

=head1 SEE ALSO

required L<Crypt::SSLeay> for C<https> connection

=cut

use Moose;
use HTTP::Request;
use HTTP::Response;
use LWP::UserAgent;
extends 'Horris::Connection::Plugin';
with 'MooseX::Role::Pluggable::Plugin';

sub irc_privmsg {
    my ($self, $message) = @_;
    my $msg = $self->_parse_status($message);

    return $self->pass unless defined $msg;

    for my $m (split(/\n/, $msg)) {
        $self->connection->irc_privmsg({
            channel => $message->channel,
            message => $m
        });
    }

    return $self->done;
}

sub _parse_status {
    my ($self, $message) = @_;
    my $raw = $message->message;
    $raw =~ s/#!\///;
    my $url;
    unless (($url) = $raw =~ m{(https?://(:?.*)twitter\.com/(:?[^/]+)/st\w+/[0-9]+)}) { # status, statuses
        return undef;
    }

    print "recv Twitter URI\n" if $Horris::DEBUG;

    my ($msg, $nick);
    my $request  = HTTP::Request->new( GET => $url );
    my $ua       = LWP::UserAgent->new;
    my $response = $ua->request($request);
    if ($response->is_success) {
        if ($url =~ /mobile\./i) {
            ($msg) = $response->content =~ m{<span class="status">(.*)</span>}m;
            ($nick) = $url =~ m{(\w+)/status};
            $msg =~ s{<[^>]*>}{}g;
        } else {
            ($nick) = $response->content =~ m{<title id="page_title">Twitter / ([^:]*)};
            ($msg) = $response->content =~ m{<meta content="([^"]*)" name="description" />}m;
        }

        $msg =~ s/&amp;/&/g;
        $msg =~ s/&lt;/</g;
        $msg =~ s/&gt;/>/g;
        $msg =~ s/&quot;/"/g;
        $msg = $nick . ': ' . $msg;
    } else {
        $msg = $response->status_line unless $response->is_success;
    }
    return $msg;
}

__PACKAGE__->meta->make_immutable;

1;
