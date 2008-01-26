# ===========================================================================
# Copyright 2005, Everitz Consulting (mt@everitz.com)
# ===========================================================================
package MT::Plugin::AltEntries;

use base qw(MT::Plugin);
use strict;

use MT;

# version
use vars qw($VERSION);
$VERSION = '0.1.1';

my $about = {
  name => 'MT-AltEntries',
  description => 'Alternate entries if category is empty.',
  author_name => 'Everitz Consulting',
  author_link => 'http://www.everitz.com/',
  version => $VERSION,
};
MT->add_plugin(new MT::Plugin($about));

use MT::Template::Context;
MT::Template::Context->add_container_tag(AltEntries => \&AltEntries);

sub AltEntries {
  my($ctx, $args, $cond) = @_;

  # blog id
  my $blog_id = $ctx->stash('blog_id');

  # entry stuff
  require MT::Entry;
  my @entries;

  # entries by category
  if (my $category = $args->{category}) {
    require MT::Category;
    my $cat = MT::Category->load({
      'blog_id' => $blog_id,
      'label' => $category
    });
    if ($cat) {
      my %entries;
      require MT::Placement;
      my @placements = MT::Placement->load({
        'blog_id' => $blog_id,
        'category_id' => $cat->id
      });
      for my $place (@placements) {
        $entries{$place->entry_id}++;
      }
      @entries = map { MT::Entry->load($_) } keys (%entries);
      if (my $n = $args->{lastn}) {
        @entries = sort { $b->created_on cmp $a->created_on } @entries;
        my @work_entries;
        for (my $x = 0; $x < $n; $x++) {
          push @work_entries, $entries[$x];
        }
        @entries = @work_entries;
      }
      my $app = MT->instance;
      $app->log('cat entries: '.scalar @entries);
    }
  }

  unless (scalar (@entries)) {
    my (%args, %terms);
    $args{'direction'} = 'descend';
    $args{'sort'} = 'created_on';
    if (my $n = $args->{lastn}) {
      $args{'limit'} = $n;
    }
    $terms{'blog_id'} = $blog_id;
    $terms{'status'} = MT::Entry::RELEASE();
    @entries = MT::Entry->load(\%terms, \%args);
    my $app = MT->instance;
    $app->log('all entries: '.$blog_id.' '.scalar @entries);
  }

  # tbd: use the join method to pull entries?
  @entries = MT::Entry->load(undef, {
    'join' => [ 'MT::Placement', 'entry_id', { 'category_id' => 40, 'is_primary' => 1 } ],
    'limit' => 3,
  });

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
