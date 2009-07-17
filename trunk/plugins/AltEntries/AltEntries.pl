# ===========================================================================
# A Movable Type plugin to load alternate entries from another category.
# Copyright 2005 Everitz Consulting <everitz.com>.
#
# This program is free software:  You may redistribute it and/or modify it
# it under the terms of the Artistic License version 2 as published by the
# Open Source Initiative.
#
# This program is distributed in the hope that it will be useful but does
# NOT INCLUDE ANY WARRANTY; Without even the implied warranty of FITNESS
# FOR A PARTICULAR PURPOSE.
#
# You should have received a copy of the Artistic License with this program.
# If not, see <http://www.opensource.org/licenses/artistic-license-2.0.php>.
# ===========================================================================
package MT::Plugin::AltEntries;

use base qw(MT::Plugin);
use strict;

use MT;

# version
use vars qw($VERSION);
$VERSION = '0.1.4';

my $about = {
  name => 'MT-AltEntries',
  description => 'Load alternate entries from another category.',
  author_name => 'Everitz Consulting',
  author_link => 'http://everitz.com/',
  version => $VERSION,
};
MT->add_plugin(new MT::Plugin($about));

use MT::Template::Context;
MT::Template::Context->add_container_tag(AltEntries => \&AltEntries);

sub AltEntries {
  my($ctx, $args, $cond) = @_;

  # blog id
  my $blog_id = $ctx->stash('blog_id');

  # limit results
  my $lastn = $args->{lastn} || 0;

  # entry stuff
  require MT::Entry;
  my @entries;

  # common parms
  my %terms = (
    'blog_id' => $blog_id,
    'status' => MT::Entry::RELEASE
  );
  my %args = (
    'direction' => 'descend',
    'limit' => $lastn,
    'sort' => 'authored_on'
  );

  # entries by category
  if (my $category = $args->{category}) {
    require MT::Category;
    my $cat = MT::Category->load({
      'blog_id' => $blog_id,
      'label' => $category
    });
    if ($cat) {
      $args{'join'} = [ 'MT::Placement', 'entry_id', { 'category_id' => $cat->id } ];
    }
    @entries = MT::Entry->load(\%terms, \%args);
  }

  unless (scalar (@entries)) {
    undef $args{'join'};
    @entries = MT::Entry->load(\%terms, \%args);
  }

  my $builder = $ctx->stash('builder');
  my $tokens = $ctx->stash('tokens');
  my $res = '';

  foreach (@entries) {
    eval ("use MT::Promise qw(delay);");
    $ctx->{__stash}{entry} = $_ if $@;
    $ctx->{__stash}{entry} = delay (sub { $_; }) unless $@;
    my $out = $builder->build($ctx, $tokens);
    return $ctx->error($builder->errstr) unless defined $out;
    $res .= $out;
  }
  $res;
}

1;
