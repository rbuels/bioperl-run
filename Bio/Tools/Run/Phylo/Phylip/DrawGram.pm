# $Id $
#
# BioPerl module for Bio::Tools::Run::Phylo::Phylip::DrawGram
#
# Cared for by Jason Stajich <jason@bioperl.org>
#
# Copyright Jason Stajich
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::Run::Phylo::Phylip::DrawGram - DESCRIPTION of Object

=head1 SYNOPSIS

use Bio::Tools::Run::Phylo::Phylip::DrawGram;

my $drawfact = new Bio::Tools::Run::Phylo::Phylip::DrawGram();
my $treeimage = $drawfact->draw_tree($tree);

=head1 DESCRIPTION

This is a module for automating drawing of trees through Joe
Felsenstein's Phylip suite.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org              - General discussion
  http://bioperl.org/MailList.shtml  - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via
email or the web:

  bioperl-bugs@bioperl.org
  http://bugzilla.bioperl.org/

=head1 AUTHOR - Jason Stajich

Email jason@bioperl.org

Describe contact details here

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Tools::Run::Phylo::Phylip::DrawGram;
use vars qw($AUTOLOAD @ISA $PROGRAM $PROGRAMDIR $PROGRAMNAME
	    $FONTFILE $TMPDIR @DRAW_PARAMS @OTHER_SWITCHES
	    %OK_FIELD %DEFAULT);
use strict;

use Bio::Tools::Run::Phylo::Phylip::Base;
use Cwd;
@ISA = qw( Bio::Tools::Run::Phylo::Phylip::Base );

# inherit from Phylip::Base which has some methods for dealing with
# Phylip specifics
@ISA = qw(Bio::Tools::Run::Phylo::Phylip::Base);

# You will need to enable the neighbor program. This
# can be done in (at least) 3 ways:
#
# 1. define an environmental variable PHYLIPDIR:
# export PHYLIPDIR=/home/shawnh/PHYLIP/bin
#
# 2. include a definition of an environmental variable PHYLIPDIR in
# every script that will use DrawGram.pm.
# $ENV{PHYLIPDIR} = '/home/shawnh/PHYLIP/bin';
#
# 3. You can set the path to the program through doing:
# my @params('program'=>'/usr/local/bin/drawgram');
# my $neighbor_factory = Bio::Tools::Run::Phylo::Phylip::DrawGram->new(@params)

BEGIN {
    %DEFAULT = ('PLOTTER' => 'L',
		'SCREEN'  => 'N');
		
    $PROGRAMNAME="drawgram";
    if (defined $ENV{'PHYLIPDIR'}) {
	$PROGRAMDIR = $ENV{'PHYLIPDIR'} || '';
	$PROGRAM = Bio::Root::IO->catfile($PROGRAMDIR,
					  $PROGRAMNAME.($^O =~ /mswin/i ?'.exe':''));	
	$DEFAULT{'FONTFILE'} = Bio::Root::IO->catfile($ENV{'PHYLIPDIR'},"font1");
    }
    else {
	$PROGRAM = $PROGRAMNAME;
    }

    @DRAW_PARAMS = qw(PLOTTER SCREEN TREEDIR TREESTYLE USEBRANCHLENS
		      LABEL_ANGLE HORIZMARGINS VERTICALMARGINS
		      SCALE TREEDEPTH STEMLEN TIPSPACE ANCESTRALNODES
		      FONT);
    @OTHER_SWITCHES = qw(QUIET);
    foreach my $attr(@DRAW_PARAMS,@OTHER_SWITCHES) {
	$OK_FIELD{$attr}++;
    }
}

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::Run::Phylo::Phylip::DrawGram();
 Function: Builds a new Bio::Tools::Run::Phylo::Phylip::DrawGram object 
 Returns : an instance of Bio::Tools::Run::Phylo::Phylip::DrawGram
 Args    : The available DrawGram parameters


=cut

sub new {
  my($class,@args) = @_;

  my $self = $class->SUPER::new(@args);
  # to facilitiate tempfile cleanup
  $self->io->_initialize_io();
  
  my ($attr, $value);
  ($TMPDIR) = $self->io->tempdir(CLEANUP=>1);
  
  while (@args)  {
      $attr =   shift @args;
      $value =  shift @args;
      next if( $attr =~ /^-/ ); # don't want named parameters
      if ($attr =~/PROGRAM/i) {
	  $self->executable($value);
	  next;
      }      
      $self->$attr($value);
  }
  $self->plotter($DEFAULT{'PLOTTER'}) unless $self->plotter;
  $self->screen($DEFAULT{'SCREEN'}) unless $self->screen;  
  $self->fontfile($DEFAULT{'FONTFILE'}) unless $self->fontfile;
  return $self;
}


sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*:://;
    $attr = uc $attr;
    $self->throw("Unallowed parameter: $attr !") unless $OK_FIELD{$attr};
    $self->{$attr} = shift if @_;
    return $self->{$attr};
}

=head2 executable

 Title   : executable
 Usage   : $obj->executable($newval)
 Function: Finds the full path to the 'drawgram' executable
 Returns : string representing the full path to the exe
 Args    : [optional] name of executable to set path to 
           [optional] boolean flag whether or not warn when exe is not found

=cut

sub executable{
   my ($self, $exe,$warn) = @_;

   if( defined $exe ) {
     $self->{'_pathtoexe'} = $exe;
   }

   unless( defined $self->{'_pathtoexe'} ) {
       if( $PROGRAM && -e $PROGRAM && -x $PROGRAM ) {
	   $self->{'_pathtoexe'} = $PROGRAM;
       } else { 
	   my $exe;
	   if( ( $exe = $self->io->exists_exe($PROGRAMNAME) ) &&
	       -x $exe ) {
	       $self->{'_pathtoexe'} = $exe;
	   } else { 
	       $self->warn("Cannot find executable for $PROGRAMNAME") if $warn;
	       $self->{'_pathtoexe'} = undef;
	   }
       }
   }
   $self->{'_pathtoexe'};
}

=head2 draw_tree

 Title   : draw_tree
 Usage   : my $file = $app->draw_tree($treefile);
 Function: Draw a tree
 Returns : File containing the rendered tree 
 Args    : either a Bio::Tree::TreeI 
            OR
           filename of a tree in newick format


=cut

sub draw_tree{
   my ($self,$input) = @_;
   
   # Create input file pointer
   my ($infilename) = $self->_setinput($input);
    if (!$infilename) {
	$self->throw("Problems setting up for drawgram. Probably bad input data in $input !");
    }

    # Create parameter string to pass to neighbor program
    my $param_string = $self->_setparams();

    # run drawgram
    my $plotfile = $self->_run($infilename,$param_string);
    return $plotfile;
}


=head2  _run

 Title   :  _run
 Usage   :  Internal function, not to be called directly	
 Function:  makes actual system call to drawgram program
 Example :
 Returns : Bio::Tree object
 Args    : Name of a file the tree to draw in newick format 
           and a parameter string to be passed to drawgram


=cut

sub _run {
    my ($self,$infile,$param_string) = @_;
    my $instring;
    if( $infile ne $self->treefile ) {
	$instring =  $infile."\n";
    }
    
    if( ! defined $self->fontfile ) { 
	$self->throw("You must have defined a fontfile");
    }
    if( $self->fontfile ne 'fontfile' ) {
	$instring .=  $self->fontfile."\n";
    }
    $instring .= $param_string;
    $self->debug( "Program ".$self->executable." $param_string\n");
    # open a pipe to run drawgram to bypass interactive menus
    if ($self->quiet() || $self->verbose() < 0) {
	open(DRAW,"|".$self->executable.">/dev/null");
    }
    else {
	open(DRAW,"|".$self->executable);
    }
    print DRAW $instring;
    close(DRAW);	

    #get the results
    my $path = cwd;
    chomp($path);
    my $plotfile = $self->io->catfile($path,$self->plotfile);

    $self->throw("drawgram did not create plotfile correctly ($plotfile)")
	unless (-e $plotfile);    		
    return $plotfile;
}

=head2  _setinput()

 Title   :  _setinput
 Usage   :  Internal function, not to be called directly	
 Function:  Create input file for drawing program
 Example :
 Returns : filename containing tree in newick format
 Args    : Bio::Tree::TreeI object


=cut

sub _setinput {
    my ($self, $input) = @_;
    my $treefile;
    unless (ref $input) {
        # check that file exists or throw
        $treefile = $input;
        unless (-e $input) {return 0;}
	
    } elsif ($input->isa("Bio::Tree::TreeI")) {
        #  Open temporary file for both reading & writing of BioSeq array
	my $tfh;
	($tfh,$treefile) = $self->io->tempfile(-dir=>$TMPDIR);
	my $treeIO = Bio::TreeIO->new(-fh => $tfh, 
				      -format=>'newick');
	$treeIO->write_tree($input);
	$treeIO->close();
	close($tfh);
    }
    return $treefile;
}

=head2  _setparams()

 Title   :  _setparams
 Usage   :  Internal function, not to be called directly	
 Function:   Create parameter inputs for drawgram program
 Example :
 Returns : parameter string to be passed to drawgram
 Args    : name of calling object

=cut

sub _setparams {
    my ($attr, $value, $self);

    #do nothing for now
    $self = shift;
    my $param_string = "";
    my $cat = 0;
    my ($hmargin,$vmargin);
    foreach  my $attr ( @DRAW_PARAMS) {	
	$value = $self->$attr();

	$attr = uc($attr);
	next unless (defined $value);
	if ($attr eq 'PLOTTER' ||
	    $attr eq 'SCREEN' ) {
	    # take first char of the input
	    $param_string .= uc(substr($value,0,1))."\n";
	    next;
	} elsif( $attr eq 'TREEDIR' ) { # tree direction
	    if( $value =~ /^H/i ) {
		$param_string .= "1\n";
	    }
	} elsif( $attr eq 'TREESTYLE' ) {
	    my $add = "2\n";
	    if( $value =~ /clad/i || uc(substr($value,0,1)) eq 'C'  ) {
		$add .= "C\n";
	    } elsif( $value =~ /phen/i || uc(substr($value,0,1)) eq 'P' ) {
		$add .= "P\n";
	    } elsif( $value =~ /curv/i || uc(substr($value,0,1)) eq 'V' ) {
		$add .= "V\n";
	    } elsif( $value =~ /euro/i || uc(substr($value,0,1)) eq 'E' ) {
		$add .= "E\n";
	    } elsif( $value =~ /swoop/i || uc(substr($value,0,1)) eq 'S' ) {
		$add .= "S\n";
	    } else { 
		$self->warn("Unknown requested tree output format $value\n");
		next;
	    }
	    $param_string .= $add;
	} elsif( $attr eq 'USEBRANCHLENS' ) {
	    if( uc(substr($value,0,1)) eq 'N' || $value == 0 ) {
		$param_string = "3\n";
	    }
	} elsif( $attr eq 'LABEL_ANGLE' ) {
	    if( $value !~ /(\d+(\.\d+)?)/ ||
		$1 < 0 || $1 > 90 ) {
		$self->warn("Expected a number from 0-90 in $attr\n"); 
		next;
	    }
	    $param_string .= "4\n$1\n";
	} elsif( $attr eq 'HORIZMARGINS' ) {
	    if( $value !~ /(\d+(\.\d+)?)/ ) {
		$self->warn("Expected a number in $attr\n"); 
		next;
	    }
	    $hmargin = $1;
	} elsif( $attr eq 'VERTICALMARGINS' ) {
	    if( $value !~ /(\d+(\.\d+)?)/ ) {
		$self->warn("Expected a number in $attr\n"); 
		next;
	    }
	    $vmargin = $1;
	} elsif( $attr eq 'SCALE' ) {
	    if( $value !~ /(\d+(\.\d+)?)/ ) {
		$self->warn("Expected a number in $attr\n"); 
		next;
	    }
	    $param_string .= "6\n$1";
	} elsif( $attr eq 'TREEDEPTH' ) {
	    if( $value !~ /(\d+(\.\d+)?)/ ) {
		$self->warn("Expected a number from in $attr\n"); 
		next;
	    }
	    $param_string .= "7\n$1\n";
	} elsif( $attr eq 'STEMLEN' ) {
	    if( $value !~ /(\d+(\.\d+)?)/ ||
		 $1 < 0 || $1 >= 1 ) {
		$self->warn("Expected a number from 0 to < 1 in $attr\n"); 
		next;
	    }
	    $param_string .= "8\n$1\n";
	 } elsif( $attr eq 'TIPSPACE' ) {
	     if( $value !~ /(\d+(\.\d+)?)/ ) {
		 $self->warn("Expected a number from 0 to < 1 in $attr\n"); 
		 next;
	    }
	    $param_string .= "9\n$1\n";
	 } elsif( $attr eq 'ANCESTRALNODES' ) {
	     if( $value !~ /^([IWCNV])/i ) {
		 $self->warn("Unrecognized value $value for $attr, expected one of [IWCNV]\n");
		 next;
	     }
	     $param_string .= "10\n$1\n";
	 } elsif( $attr eq 'FONT' ) {	 
	     $value =~ s/([\w\d]+)\s+/$1/g;
	     $param_string .= "11\n$value\n";
	 }
    }
    if( $hmargin || $vmargin ) {
	$hmargin ||= '.';
	$vmargin ||= '.';
	$param_string .= "5\n$hmargin\n$vmargin\n";
    }

    $param_string .="Y\n";	
    return $param_string;
}



=head1 Bio::Tools::Run::Wrapper methods

=cut

=head2 no_param_checks

 Title   : no_param_checks
 Usage   : $obj->no_param_checks($newval)
 Function: Boolean flag as to whether or not we should
           trust the sanity checks for parameter values  
 Returns : value of no_param_checks
 Args    : newvalue (optional)


=cut

=head2 save_tempfiles

 Title   : save_tempfiles
 Usage   : $obj->save_tempfiles($newval)
 Function: 
 Returns : value of save_tempfiles
 Args    : newvalue (optional)


=cut

=head2 outfile_name

 Title   : outfile_name
 Usage   : my $outfile = $dragram->outfile_name();
 Function: Get/Set the name of the output file for this run
           (if you wanted to do something special)
 Returns : string
 Args    : [optional] string to set value to


=cut


=head2 tempdir

 Title   : tempdir
 Usage   : my $tmpdir = $self->tempdir();
 Function: Retrieve a temporary directory name (which is created)
 Returns : string which is the name of the temporary directory
 Args    : none


=cut

=head2 cleanup

 Title   : cleanup
 Usage   : $codeml->cleanup();
 Function: Will cleanup the tempdir directory after a PAML run
 Returns : none
 Args    : none


=cut

=head2 io

 Title   : io
 Usage   : $obj->io($newval)
 Function:  Gets a L<Bio::Root::IO> object
 Returns : L<Bio::Root::IO>
 Args    : none


=cut

1; # Needed to keep compiler happy