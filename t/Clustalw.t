# -*-Perl-*-
## Bioperl Test Harness Script for Modules
## $Id$

use strict;
BEGIN {
    eval { require Test; };
    if( $@ ) { 
	use lib 't';
    }
    use Test;
    use vars qw($NTESTS);
    $NTESTS = 10;
    plan tests => $NTESTS;
}

use Bio::Tools::Run::Alignment::Clustalw; 
use Bio::SimpleAlign; 
use Bio::AlignIO; 
use Bio::SeqIO; 
use Bio::Root::IO;

END {     
    for ( $Test::ntest..$NTESTS ) {
	skip("Clustalw program not found. Skipping. (Be sure you have clustalw > 1.4)",1);
    }
}
ok(1);
my $verbose = -1;
my @params = ('ktuple' => 2,
	      'QUIET'  => 1,
	      -verbose => $verbose);
my  $factory = Bio::Tools::Run::Alignment::Clustalw->new(@params);

ok $factory->isa('Bio::Tools::Run::Alignment::Clustalw');

my $ktuple = 3;
$factory->ktuple($ktuple);

my $new_ktuple = $factory->ktuple();
ok $new_ktuple, 3, " couldn't set factory parameter";

my $bequiet = 1;
$factory->quiet($bequiet);  # Suppress clustal messages to terminal

my $inputfilename = Bio::Root::IO->catfile(qw(t data cysprot.fa));
my $aln;
exit(0) unless( $factory->executable );

ok ($factory->version >= 1.8, 1, "Code tested only on ClustalW versions > 1.8 ");

$aln = $factory->align($inputfilename);
my $i = 1;
for my $seq ( $aln->each_seq ) {  
    last if( $seq->display_id =~ /CATH_HUMAN/ );
    $i++;
}
ok($aln->get_seq_by_pos($i)->get_nse, 'CATH_HUMAN/1-335', 
   "failed clustalw alignment using input file");
$factory->bootstrap(100);
my $tree = $factory->tree($aln);
ok($tree);

$factory->bootstrap(undef);

my $str = Bio::SeqIO->new(-file=> $inputfilename, 
			  '-format' => 'fasta');
my @seq_array =();

while ( my $seq = $str->next_seq() ) {
	push (@seq_array, $seq) ;
    }

$aln = $factory->align(\@seq_array);


# now seen is the actual number for CATL HUMAN so that is more helpful	
$i = 1;
for my $seq ( $aln->each_seq ) {  
    last if( $seq->display_id =~ /CATH_HUMAN/ );
    $i++;
}

ok ($aln->get_seq_by_pos($i)->get_nse, 'CATH_HUMAN/1-335', 
    "failed clustalw alignment using BioSeq array ");
	
my $profile1 = Bio::Root::IO->catfile("t","data","cysprot1a.msf");
my $profile2 = Bio::Root::IO->catfile("t","data","cysprot1b.msf");
$aln = $factory->profile_align($profile1,$profile2);

$i = 1;
for my $seq ( $aln->each_seq ) {  
    last if( $seq->display_id =~ /CATH_HUMAN/ );
    $i++;
}

ok( $aln->get_seq_by_pos($i)->get_nse, 'CATH_HUMAN/1-335', 
    " failed clustalw profile alignment using input file" );

if ($factory->version > 1.82 ) {
    my $str1 = Bio::AlignIO->new(-file=> Bio::Root::IO->catfile("t","data","cysprot1a.msf"));
    my $aln1 = $str1->next_aln();
    my $str2 = Bio::AlignIO->new(-file=> Bio::Root::IO->catfile("t","data","cysprot1b.msf"));
    my $aln2 = $str2->next_aln();
    
    $aln = $factory->profile_align($aln1,$aln2);
    ok($aln->get_seq_by_pos(2)->get_nse, 'CATH_HUMAN/1-335');

    $str1 = Bio::AlignIO->new(-file=> Bio::Root::IO->catfile("t","data","cysprot1a.msf"));
    $aln1 = $str1->next_aln();
    $str2 = Bio::SeqIO->new(-file=> Bio::Root::IO->catfile("t","data","cysprot1b.fa"));
    my $seq = $str2->next_seq();
    $aln = $factory->profile_align($aln1,$seq);
    ok ($aln->get_seq_by_pos(2)->get_nse,  'CATH_HUMAN/1-335');
} else {
    skip("skipping due to clustalw 1.81 & 1.82 profile align bug",1);
    skip("skipping due to clustalw 1.81 & 1.82 profile align bug",1);
}

