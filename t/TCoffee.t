


use strict;
use vars qw($NUMTESTS);
BEGIN { 
    eval { require Test; };
    if( $@ ) {
	use lib 't';
    }
    use Test;

    $NUMTESTS = 9; 
    plan tests => $NUMTESTS; 
}

END { unlink qw(cysprot.dnd cysprot1a.dnd) }

use Bio::Tools::Run::Alignment::TCoffee;
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::SeqIO;
use Bio::Root::IO;

ok(1);


my @params = ('ktuple' => 2, 'matrix' => 'BLOSUM');
my  $factory = Bio::Tools::Run::Alignment::TCoffee->new(@params);

ok ($factory =~ /Bio::Tools::Run::Alignment::TCoffee/);


my $ktuple = 3;
$factory->ktuple($ktuple);

my $new_ktuple = $factory->ktuple();
ok $new_ktuple, 3, " couldn't set factory parameter";


my $what_matrix = $factory->matrix();
ok $what_matrix, 'BLOSUM', "couldn't get factory parameter";

my $bequiet = 1;
$factory->quiet($bequiet);  # Suppress tcoffee messages to terminal

my $inputfilename = Bio::Root::IO->catfile("t","cysprot.fa");
my $aln;


my $coffee_present = Bio::Tools::Run::Alignment::TCoffee->exists_tcoffee();
unless ($coffee_present) {
	warn "tcoffee program not found. Skipping tests $Test::ntest to $NUMTESTS.\n";
	foreach ( $Test::ntest..$NUMTESTS ) {
	    skip(1,1);
	}
	exit(0);
}
$aln = $factory->align($inputfilename);

ok ($aln->{order}->{'0'}, 'CYS1_DICDI-1-343', 
    "failed tcoffee alignment using input file");

my $str = Bio::SeqIO->new(-file=> Bio::Root::IO->catfile("t","cysprot.fa"), '-format' => 'Fasta');
my @seq_array =();

while ( my $seq = $str->next_seq() ) {
    push (@seq_array, $seq) ;
}

my $seq_array_ref = \@seq_array;

$aln = $factory->align($seq_array_ref);
	
ok($aln->{order}->{'0'}, 'CYS1_DICDI-1-343', 
   "failed tcoffee alignment using BioSeq array ");


	
my $profile1 = Bio::Root::IO->catfile("t","cysprot1a.msf");
my $profile2 = Bio::Root::IO->catfile("t","cysprot1b.msf");
$aln = $factory->profile_align($profile1,$profile2);

ok( $aln->{order}->{'1'}, 'CATL_HUMAN-1-333', 
    " failed tcoffee profile alignment using input file ". 
    $aln->{order}->{'1'} );


my $str1 = Bio::AlignIO->new(-file=> Bio::Root::IO->catfile("t","cysprot1a.msf"));
my $aln1 = $str1->next_aln();
my $str2 = Bio::AlignIO->new(-file=> Bio::Root::IO->catfile("t","cysprot1b.msf"));
my $aln2 = $str2->next_aln();

$aln = $factory->profile_align($aln1,$aln2);
ok ( $aln->{order}->{'1'}, 'CATL_HUMAN-1-333', 
     "failed tcoffee profile alignment using SimpleAlign input ". 
     $aln->{order}->{'1'});


$str1 = Bio::AlignIO->new(-file=> Bio::Root::IO->catfile("t","cysprot1a.msf"));
$aln1 = $str1->next_aln();
$str2 = Bio::SeqIO->new(-file=> Bio::Root::IO->catfile("t","cysprot1b.fa"));
my $seq = $str2->next_seq();
$aln = $factory->profile_align($aln1,$seq);

ok( $aln->{order}->{'1'}, 'CATH_RAT-1-333', 
    "failed adding new sequence to alignment ". $aln->{order}->{'1'});
