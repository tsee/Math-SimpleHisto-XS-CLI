package Math::SimpleHisto::XS::CLI;
use 5.008001;
use strict;
use warnings;

our $VERSION = '1.05';

use constant BATCHSIZE => 1000;
use Carp 'croak';
use Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
  histogram_from_dumps_fh
  histogram_from_random_data
  histogram_from_fh
  histogram_slurp_from_fh
  minmax
  display_histogram_using_soot

  intuit_ascii_style
);
our %EXPORT_TAGS = (
  'all' => \@EXPORT_OK,
);

use Math::SimpleHisto::XS;

sub histogram_from_dumps_fh {
  my ($fh) = @_;

  my $hist;
  my $tmphist;
  #require Math::SimpleHisto::XS::Named; # TODO implement & test using this
  while (my $dump = <$fh>) {
    next if not $dump =~ /\S/;
    foreach my $type (qw(json yaml simple)) {
      eval {$tmphist = Math::SimpleHisto::XS->new_from_dump($type, $dump);};
      last if defined $tmphist;
    }
    if (defined $tmphist) {
      if ($hist) { $hist->add_histogram($tmphist) }
      else { $hist = $tmphist }
    }
  }
  Carp::croak("Could not recreate histogram from input histogram dump string")
    if not defined $hist;

  return $hist;
}

sub histogram_from_random_data {
  my ($histopt, $random_samples) = @_;
  my %opt = %$histopt;
  $opt{min} ||= 0;
  $opt{max} ||= 1;
  $random_samples = 1000 if not $random_samples;

  my $hist = Math::SimpleHisto::XS->new(
    min   => $opt{min},
    max   => $opt{max},
    nbins => $opt{nbins},
  );

  my $min = $hist->min;
  my $width = $hist->width;
  $hist->fill($min + rand($width)) for 1..$random_samples;

  return $hist;
}

sub histogram_from_fh {
  my ($histopt, $fh) = @_;
  
  my $hist = Math::SimpleHisto::XS->new(map {$_ => $histopt->{$_}} qw(nbins min max));

  my $pos_weight = $histopt->{xw};
  my (@coords, @weights);
  my $i = 0;
  while (<STDIN>) {
    chomp;
    my @row = split " ", $_;
    if ($pos_weight) {
      push @{ (++$i % 2) ? \@coords : \@weights }, $_ for split " ", $_;
    }
    else {
      push @coords, split " ", $_;
    }
    if (@coords >= BATCHSIZE) {
      my $tmp;
      $tmp = pop(@weights) if @coords != @weights;
      $hist->fill($pos_weight ? (\@coords, \@weights) : (\@coords));

      @coords = ();
      @weights = (defined($tmp) ? ($tmp) : ());
    }
  }

  $hist->fill($pos_weight ? (\@coords, \@weights) : (\@coords))
    if @coords;

  return $hist;
}

# modifies input options
sub histogram_slurp_from_fh {
  my ($histopt, $fh) = @_;

  my $pos_weight = $histopt->{xw};
  my $hist;
  my (@coords, @weights);
  my $i = 0;
  while (<STDIN>) {
    chomp;
    s/^\s+//; s/\s+$//;
    if ($pos_weight) {
      push @{ (++$i % 2) ? \@coords : \@weights }, $_ for split " ", $_;
    }
    else {
      push @coords, split " ", $_;
    }
  }

  # Without input and configured histogram boundaries, we can't make one
  # TODO: should this be silent "success" or an empty histogram (for dump
  #       output mode) or an exception?
  exit(0) if not @coords;
  my ($min, $max) = minmax(@coords);
  $histopt->{min} = $min if not defined $histopt->{min};
  $histopt->{max} = $max if not defined $histopt->{max};

  $hist = Math::SimpleHisto::XS->new(map {$_ => $histopt->{$_}} qw(nbins min max));
  $hist->fill($pos_weight ? (\@coords, \@weights) : (\@coords));

  return $hist;
}

sub minmax {
  my ($min, $max);
  for (@_) {
    $min = $_ if not defined $min or $min > $_;
    $max = $_ if not defined $max or $max < $_;
  }
  return($min, $max);
}

sub display_histogram_using_soot {
  my ($hist) = @_;
  my $h = $hist->to_soot;
  my $cv = TCanvas->new;
  $h->Draw();
  my $app = $SOOT::gApplication = $SOOT::gApplication; # silence warnings
  $app->Run();
  exit;
}

our %AsciiStyles = (
  '-' => {character => '-', end_character => '>'},
  '=' => {character => '=', end_character => '>'},
  '~' => {character => '~', end_character => '>'},
);

# Determine the style to use for drawing the histogram
sub intuit_ascii_style {
  my ($style_option) = @_;
  $style_option = '~' if not defined $style_option;
  if (not exists $AsciiStyles{$style_option}) {
    if (length($style_option) == 1) {
      $AsciiStyles{$style_option} = {character => $style_option, end_character => $style_option};
    }
    else {
      die "Invalid histogram style '$style_option'. Valid styles: '"
          . join("', '", keys %AsciiStyles), "' and any single character.\n";
    }
  }

  my $styledef = $AsciiStyles{$style_option};
  return $styledef;
}

1;
__END__

=head1 NAME

Math::SimpleHisto::XS::CLI - Tools for the CLI tools

=head1 SYNOPSIS

  See the 'histify' and 'drawasciihist' CLI tools!

=head1 DESCRIPTION

This is a dummy module that simply serves as a way to make the
L<Math::SimpleHisto::XS>-related CLI tools installable separately
from the main module.

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, 2012 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
