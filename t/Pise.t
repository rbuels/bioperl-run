# -*-Perl-*- mode
use strict;
BEGIN {
    use vars qw($NTESTS $error);
    # to handle systems with no installed Test module
    # we include the t dir (where a copy of Test.pm is located)
    # as a fallback
    $error = 0;
    eval { require Test; };
    if( $@ ) {
	use lib 't';
    }
    use Test;
    $NTESTS = 10;
    plan tests => $NTESTS; 
    eval { require XML::Parser::PerlSAX;};
    if ($@) { 
       print STDERR "Need XML::Parser::PerlSA to run test, skipping test\n";
       foreach ( $Test::ntest .. $NTESTS ) {
          skip("unable to the Pise tests -- Need XML::Parser::PerlSAX",1);
       }
    exit(0);
    }
}

if( $error ==  1 ) {
    exit(0);
}
END { 
    foreach ( $Test::ntest .. $NTESTS ) {
	skip("unable to the Pise tests -- no network connection or site is down",1);
    }
}
use Bio::Factory::Pise;
use Bio::Tools::Genscan;
use Bio::SeqIO;

exit(0);
my $golden_outfile = 'golden.out';
my $actually_submit;

END {
    if ($actually_submit) {
	for ( $Test::ntest..$NTESTS ) {
	    skip("Unable to run Pise tests - probably no network connection.",1);
	}
	unlink($golden_outfile);
    } else {
	for ( $Test::ntest..3 ) {
	    skip("Unable to run Pise tests.",1);
	}
    }
}

my $verbose = $ENV{'BIOPERLDEBUG'} || -1;
ok(1);
my $email;
if( -e "t/pise-email.test" ) {
    if( open(T, "t/pise-email.test") ) {
	chomp($email = <T>);
    } else { 
	print "skipping tests, cannot run without read access to testfile data";
	exit;
    }
}

my $factory = Bio::Factory::Pise->new(-email => $email);
ok($factory);

my $golden = $factory->program('golden', 
			       -db => 'genbank', 
			       -query => 'HUMRASH');
ok($golden->isa('Bio::Tools::Run::PiseApplication::golden'));

$actually_submit = 1;
#prompt('Actually submit? ',1);

if ($actually_submit) {
    my $job = $golden->run();
    ok($job->isa('Bio::Tools::Run::PiseJob'));

    if ($job->error) {
	print STDERR "Error: ", $job->error_message, "\n";
    }
    ok(! $job->error);

    $job->save($golden_outfile);
    ok (-e $golden_outfile);

    my $in = Bio::SeqIO->new ( -file   => $golden_outfile,
			       -format => 'genbank');
    my $seq = $in->next_seq();
    my $genscan = $factory->program('genscan',
				    -parameter_file => "HumanIso.smat",
				    );
    ok($genscan->isa('Bio::Tools::Run::PiseApplication::genscan'));

    $genscan->seq($seq);
    ok(1);

    $job = $genscan->run();
    ok($job->isa('Bio::Tools::Run::PiseJob'));

    my $parser = Bio::Tools::Genscan->new(-fh => $job->fh('genscan.out'));
    ok($parser->isa('Bio::Tools::Genscan'));
}


