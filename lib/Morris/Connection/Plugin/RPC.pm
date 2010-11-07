package Morris::Connection::Plugin::RPC;
use Moose;
use AnyEvent::MP qw(configure port rcv);
use AnyEvent::MP::Global qw(grp_reg);
use namespace::clean -except => qw/meta/;
extends 'Morris::Connection::Plugin';
with 'MooseX::Role::Pluggable::Plugin';

has '+is_enable' => (
	default => 0
);

after init => sub {
	my $self = shift;
	configure nodeid => "eg_receiver", binds => ["*:4040"];
	my $port = port;
	grp_reg eg_receivers => $port;
	rcv $port, test => sub {
		my ($data) = @_;
		$self->connection->irc_privmsg({
			channel => '#aanoaa', # for test
			message => $data
		});
	}
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 NAME

Morris::Connection::Plugin::RPC

=head1 SYNOPSIS

	...

=cut
