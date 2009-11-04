package Morris::Connection;
use Moose;
use AnyEvent::IRC::Client;
use Morris::Message;
use namespace::clean -except => qw(meta);

has irc => (
    is => 'rw',
    isa => 'AnyEvent::IRC::Client',
    handles => {
        send_srv => 'send_srv',
    }
);

has hooks => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
);

has server => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has plugins => (
    is => 'ro',
    isa => 'ArrayRef',
    writer => 'set_plugins'
);

has port => (
    is => 'ro',
    isa => 'Str',
    default => 6667,
    required => 1
);

has nickname => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has password => (
    is => 'ro',
    isa => 'Str',
);

sub _build_hooks { {} }

sub new_from_config {
    my ($class, $config) = @_;

    my $plugins = delete $config->{plugin};
    my $self = $class->new(%$config);
    my @plugins;
    while ( my ($class, $p) = each %$plugins ) {
        if ($class !~ s/^\+//) {
            $class = "Morris::Plugin::$class";
        }
        if (! Class::MOP::is_class_loaded( $class) ) {
            Class::MOP::load_class( $class );
        }

        my $plugin = $class->new_from_config( $p );
        $plugin->register( $self );
        push @plugins, $plugin;
    }
    $self->set_plugins(\@plugins);
    return $self;
}

sub call_hook {
    my ($self, $name, @args) = @_;

warn "Calling hooks for $name";

    my $hooks = $self->hooks->{$name};
    return unless $hooks;

    foreach my $hook (@$hooks) {
        $hook->( @args );
    }
}

sub register_hook {
    my ($self, $name, $code) = @_;

    $self->hooks->{$name} ||= [];
    my $list = $self->hooks->{$name};
    push @$list, $code;
}

sub run {
    my $self = shift;

    my $irc = AnyEvent::IRC::Client->new();
    $self->irc($irc);
    $irc->connect( $self->server, $self->port, {
        nick => $self->nickname,
        user => $self->nickname,
        password => $self->password,
        timeout => 1,
    } );
    $irc->reg_cb(
        connect     => sub { $self->call_hook( 'server.connected', @_ ) },
        disconnect  => sub { $self->call_hook( 'server.disconnect', @_ ) },
        irc_privmsg => sub { 
            my ($nick, $raw) = @_;
            my $message = Morris::Message->new(
                channel => $raw->{params}->[0],
                message => $raw->{params}->[1],
                from    => $raw->{prefix},
            );
            $self->call_hook( 'chat.privmsg', $message )
        },

        # XXX - we want the /full/ details of this user, not his nick
        #       so we override the original irc_join callback
        irc_join => sub { 
            my $object = shift;
            $object->AnyEvent::IRC::Client::join_cb(@_);
            # and /THEN/ call our callback
            # fix the param thing to be just a simple 'channel' parameter
            my $channel = $_[0]->{params}->[0];
            my $addr    = Morris::Message::Address->new( $_[0]->{prefix} );
            $self->call_hook( 'channel.joined', $channel, $addr );
        },
        registered  => sub { $self->call_hook( 'server.registered', @_ ) },
    );
}

sub irc_notice {
    my ($self, $args) = @_;
    $self->send_srv(NOTICE => $args->{channel} => $args->{message});
}

sub irc_privmsg {
    my ($self, $args) = @_;
    $self->send_srv(PRIVMSG => $args->{channel} => $args->{message});
}

sub irc_mode {
    my ($self, $args) = @_;
    $self->send_srv(MODE => $args->{channel} => $args->{mode}, $args->{who});
}

__PACKAGE__->meta->make_immutable();

1;
