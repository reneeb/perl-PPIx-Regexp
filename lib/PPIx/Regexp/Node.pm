=head1 NAME

PPIx::Regexp::Node - Represent a container

=head1 SYNOPSIS

 use PPIx::Regexp::Dumper;
 PPIx::Regexp::Dumper->new( 'qr{(foo)}' )->print();

=head1 INHERITANCE

 PPIx::Regexp::Node
 isa PPIx::Element

=head1 DESCRIPTION

This class represents a structural element that contains other classes.
It is an abstract class, not instantiated by the lexer.

=head1 METHODS

This class provides the following public methods. Methods not documented
here are private, and unsupported in the sense that the author reserves
the right to change or remove them without notice.

=cut

package PPIx::Regexp::Node;

use strict;
use warnings;

use base qw{ PPIx::Regexp::Element };

use List::Util qw{ max };
use Params::Util 0.25 qw{ _INSTANCE };
use PPIx::Regexp::Constant qw{ $MINIMUM_PERL };
use Scalar::Util qw{ refaddr };

our $VERSION = '0.000_02';

sub _new {
    my ( $class, @children ) = @_;
    ref $class and $class = ref $class;
    foreach my $elem ( @children ) {
	_INSTANCE( $elem, 'PPIx::Regexp::Element' ) or return;
    }
    my $self = {
	children => \@children,
    };
    bless $self, $class;
    foreach my $elem ( @children ) {
	$elem->_parent( $self );
    }
    return $self;
}

=head2 child

This method returns the child at the given index.

=cut

sub child {
    my ( $self, $inx ) = @_;
    defined $inx or $inx = 0;
    return $self->{children}[$inx];
}

=head2 children

This method returns the children of the Node. If called in scalar
context it returns the number of children.

=cut

sub children {
    my ( $self ) = @_;
    return @{ $self->{children} };
}

=head2 contains

This method returns true if the given element is contained in the Node,
or false otherwise.

=cut

sub contains {
    my ( $self, $elem ) = @_;
    _INSTANCE( $elem, 'PPIx::Regexp::Element' ) or return;

    my $addr = refaddr( $self );

    while ( $elem = $elem->parent() ) {
	$addr == refaddr( $elem ) and return 1;
    }

    return;
}

sub content {
    my ( $self ) = @_;
    return join( '', map{ $_->content() } $self->elements() );
}

=head2 elements

This method returns the elements in the Node. For a
C<PPIx::Regexp::Node> proper, it is the same as C<children()>.

=cut

{
    no warnings qw{ once };
    *elements = \&children;
}

=head2 find

This method finds things.

If given a string as argument, it is assumed to be a class name
(possibly without the leading 'PPIx::Regexp::'), and all elements of the
given class are found.

If given a code reference, that code reference is called once for each
element, and passed C<$self> and the element. The code should return
true to accept the element, false to reject it, and ( for subclasses of
C<PPIx::Regexp::Node>) C<undef> to prevent recursion into the node. If
the code throws an exception, you get nothing back from this method.

Either way, the return is a reference to the list of things found, a
false (but defined) value if nothing was found, or C<undef> if an error
occurred.

=cut

sub _find_routine {
    my ( $want ) = @_;
    ref $want eq 'CODE' and return $want;
    ref $want and return;
    $want =~ m/ \A PPIx::Regexp:: /smx
	or $want = 'PPIx::Regexp::' . $want;
    return sub {
	return _INSTANCE( $_[1], $want ) ? 1 : 0;
    };
}

sub find {
    my ( $self, $want ) = @_;

    $want = _find_routine( $want ) or return;

    my @found;

    # We use a recursion to find what we want. PPI::Node uses an
    # iteration.
    foreach my $elem ( $self->elements() ) {
	my $rslt = eval { $want->( $self, $elem ) }
	    and push @found, $elem;
	$@ and return;

	_INSTANCE( $elem, 'PPIx::Regexp::Node' ) or next;
	defined $rslt or next;
	$rslt = $elem->find( $want )
	    and push @found, @{ $rslt };
    }

    return @found ? \@found : 0;

}

=head2 find_first

This method has the same arguments as C<find()>, but returns either a
reference to the first element found, a false (but defined) value if no
elements were found, or C<undef> if an error occurred.

=cut

sub find_first {
    my ( $self, $want ) = @_;

    $want = _find_routine( $want ) or return;

    # We use a recursion to find what we want. PPI::Node uses an
    # iteration.
    foreach my $elem ( $self->elements() ) {
	my $rslt = eval { $want->( $self, $elem ) }
	    and return $elem;
	$@ and return;

	_INSTANCE( $elem, 'PPIx::Regexp::Node' ) or next;
	defined $rslt or next;

	defined( $rslt = $elem->find_first( $want ) )
	    or return;
	$rslt and return $rslt;
    }

    return 0;

}

=head2 first_element

This method returns the first element in the node.

=cut

sub first_element {
    my ( $self ) = @_;
    return $self->{children}[0];
}

=head2 last_element

This method returns the last element in the node.

=cut

sub last_element {
    my ( $self ) = @_;
    return $self->{children}[-1];
}

=head2 perl_version_introduced

This method returns the maximum value of C<perl_version_introduced>
returned by any of its elements. In other words, it returns the minimum
version of Perl under which this node is valid. If there are no
elements, 5.006 is returned, since that is the minimum value of Perl
supported by this package.

=cut

sub perl_version_introduced {
    my ( $self ) = @_;
    return max( $MINIMUM_PERL,
	map { $_->perl_version_introduced() } $self->elements() );
}

=head2 perl_version_removed

This method returns the minimum defined value of C<perl_version_removed>
returned by any of the node's elements. In other words, it returns the
lowest version of Perl in which this node is C<not> valid. If there are
no elements, or if no element has a defined C<perl_version_removed>,
C<undef> is returned.

=cut

sub perl_version_removed {
    my ( $self ) = @_;
    my $max;
    foreach my $elem ( $self->elements() ) {
	if ( defined ( my $ver = $elem->perl_version_removed() ) ) {
	    if ( defined $max ) {
		$ver < $max and $max = $ver;
	    } else {
		$max = $ver;
	    }
	}
    }
    return $max;
}

=head2 schild

This method returns the significant child at the given index; that is,
C<< $node->schild(0) >> returns the first significant child,
C<< $node->schild(1) >> returns the second significant child, and so on.
Negative indices count from the end.

=cut

sub schild {
    my ( $self, $inx ) = @_;
    defined $inx or $inx = 0;

    my $kids = $self->{children};

    if ( $inx >= 0 ) {

	my $loc = 0;

	while ( exists $kids->[$loc] ) {
	    $kids->[$loc]->significant() or next;
	    --$inx >= 0 and next;
	    return $kids->[$loc];
	} continue {
	    $loc++;
	}

    } else {

	my $loc = -1;
	
	while ( exists $kids->[$loc] ) {
	    $kids->[$loc]->significant() or next;
	    $inx++ < -1 and next;
	    return $kids->[$loc];
	} continue {
	    --$loc;
	}

    }

    return;
}

=head2 schildren

This method returns the significant children of the node.

=cut

sub schildren {
    my ( $self ) = @_;
    if ( wantarray ) {
	return ( grep { $_->significant() } @{ $self->{children} } );
    } elsif ( defined wantarray ) {
	my $kids = 0;
	foreach ( @{ $self->{children} } ) {
	    $_->significant() and $kids++;
	}
	return $kids;
    } else {
	return;
    }
}

sub tokens {
    my ( $self ) = @_;
    return ( map { $_->tokens() } $self->elements() );
}

# Help for nav();
sub _nav {
    my ( $self, $child ) = @_;
    refaddr( $child->parent() ) == refaddr( $self )
	or return;
    my ( $method, $inx ) = $child->_my_inx()
	or return;

    return ( $method => [ $inx ] );
}

# Called by the lexer once it has done its worst to all the tokens.
# Called as a method with no arguments. The return is the number of
# parse failures discovered when finalizing.
sub __PPIX_LEXER__finalize {
    my ( $self ) = @_;
    my $rslt = 0;
    foreach my $elem ( $self->elements() ) {
	$rslt += $elem->__PPIX_LEXER__finalize();
    }
    return $rslt;
}

# Called by the lexer to record the capture number.
sub __PPIX_LEXER__record_capture_number {
    my ( $self, $number ) = @_;
    foreach my $kid ( $self->children() ) {
	$number = $kid->__PPIX_LEXER__record_capture_number( $number );
    }
    return $number;
}

1;

__END__

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT

Copyright 2009 by Thomas R. Wyant, III.

=cut

# ex: set textwidth=72 :
