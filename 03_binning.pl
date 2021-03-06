#!/usr/bin/perl

use warnings;
use strict;
use Time::Piece ':override';
use Time::Seconds;
use Data::Dumper;
use feature ':5.10';
use PDL;
use Getopt::Long 'HelpMessage';

select STDOUT;
$| = 1;

my ($FILE_IN, $FILE_OUT, $PCT_INTERVAL, $PCT_RANGE);

GetOptions( 
    'file=s' => \$FILE_IN,
    'out=s' => \$FILE_OUT,
    'interval=i' => \$PCT_INTERVAL,
    'range=s{,}' => \$PCT_RANGE
)  or die "Invalid options passed to $0\n";

die "$0 requires the input filename argument (--file)\n" unless $FILE_IN;
die "$0 requires the output filename argument (--out)\n" unless $FILE_OUT;

my %PCT_RANGE_INTERVALS = (
    '2' => [ 50 ],
    '4' => [ 50 ],
    '6' => [ 30, 60 ],
    '8' => [ 25, 50, 75 ],
    '10' => [ 25, 50, 75 ]
);

my $pct_range = [ 25, 50, 75 ];

if ( $PCT_RANGE ) {
    $pct_range = [];
    for ( split ',', $PCT_RANGE ) { push @$pct_range, ($_ + 0); }
    say "You set range: [ 0, ". (join ', ', @$pct_range) .' ]';
} elsif ( $PCT_INTERVAL && exists $PCT_RANGE_INTERVALS{ $PCT_INTERVAL } ) {
    $pct_range = $PCT_RANGE_INTERVALS{ $PCT_INTERVAL };
}

sub main {
    my ( $line, $key, $i, $j, $file, $fh, $len );

    open $fh, '<', $FILE_IN or die $!;

    my ( %backet, %boundary, %vars, %data, @keys );

    $i = 0;
    while ( $line = <$fh> ) {

        # Отбрасываем заголовок
        unless ($i) { ++$i; next; }

        # Убираем лишние знаки
        $line =~ s/\n$//;
        $line =~ s/^\"|\"$//g;
        $line =~ s/\s*//g;

        (   $vars{'src'}, $vars{'dst'}, $vars{'dstp'}, $vars{'fph'},
            $vars{'ppf'}, $vars{'bpp'}, $vars{'bps'}
        ) = split /\";\"/, $line;

        $key = join '', @{ \%vars }{qw/src dst dstp/};
        $key =~ s/\D//g;
        $key = $i.$key;

        push @keys, $key;

        map { $data{$key}->{$_} = $vars{$_} } qw/src dst dstp/;
        map { $data{$key}->{$_} = undef } qw/fph ppf bpp bps/;

        map {
            $j = [ split ',', $vars{$_} ];
            $data{$key}->{$_} = $j;
            push @{ $vars{ '_' . $_ } }, @$j;
        } qw/fph ppf bpp bps/;

        ++$i;

    }
    close $fh;
    undef $fh;

    # Определим интервалы
    my ( $y, $z );
    foreach $y (qw/fph ppf bpp bps/) {
        push @{ $boundary{$y} }, "0";
        map {
            $z = &PDL::pctover( pdl( $vars{ '_' . $y } ), $_ / 100 );
            push @{ $boundary{$y} }, qq{$z};
        } @$pct_range;

        undef $vars{ '_' . $_ } if $_;
        delete $vars{ '_' . $_ } if $_;
    }

    open $fh, '>', $FILE_OUT or die $!;
    print $fh qq{"src_ip";"dst_ip";"dst_port";"fph";"ppf";"bpp";"bps"\n};

    $key = $y = $z = $i = $j = $len = undef;
    my $crit;
    while ( $key = shift @keys ) {

        foreach $crit (qw/fph ppf bpp bps/) {

            $len = scalar @{ $boundary{$crit} };
            for ( 1 .. $len ) { push @{ $data{$key}->{ '_' . $crit } }, 0; }

            for $j ( @{ $data{$key}->{$crit} } ) {
                # say qq{[$j]};

                for ( $i = 0; $i < $len; ++$i ) {
                    ( $y, $z ) = @{ $boundary{$crit} }[ $i .. $i + 1 ];

                    if (   ( defined $y && defined $z )
                        && ( $j < $y || $j <= $z ) )
                    {
                        $data{$key}->{ '_' . $crit }->[$i] += 1;
                        last;
     					# say '(rule 1) $j('.$j.') < $y('.$y.') || $j('.$j.') <= $z('.$z.') '.$i;
                    }

                    if ( !defined $z && ( $j > $y ) ) {
                        $data{$key}->{ '_' . $crit }->[$i] += 1;
                        last;
                        # say '(rule 2) $j('.$j.') > $y('.$y.') '.$i;
                    }
                }
            }

            $data{$key}->{ '_' . $crit } = join ',',
                @{ $data{$key}->{ '_' . $crit } };
        }
        print $fh join ';', map { qq{"$_"} } @{$data{$key}}{qw/src dst dstp _fph _ppf _bpp _bps/};
        print $fh "\n";
    }

    close $fh;
    undef $fh;

    # say 'data ', Dumper $data{$key}->{'ppf'};
    # say 'backet ', Dumper $data{$key}->{'_ppf'};
    # say 'criteria ', Dumper $boundary{$crit};
}

&main();

__END__


