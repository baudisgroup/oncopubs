#!/usr/bin/perl

use Data::Dumper;
use JSON::XS;
use MongoDB;
use MongoDB::MongoClient;
use Term::ProgressBar;
use YAML::XS;

STDOUT->autoflush(1);

my %args        =   @ARGV;

$args{'-out' }          ||=	 '..';
$args{'-coll'}          ||=  'publications_web';
$args{'-filetype'}      ||=  'yaml';            # alternative: json
$args{'-update'}        ||=  'y';
$args{'-cleanup'}       ||=  'y';

my $currentPubs =   $args{'-out' }.'/current';
my $inPubs      =   $args{'-out' }.'/incoming';
my $excludePubs =   $args{'-out' }.'/excluded';

_checkPathsExit($currentPubs, $inPubs, $excludePubs);

print <<END;

Publications will be exported as $args{'-filetype'} into

Current:
$currentPubs

For review:
$inPubs

END


my $prefix      =   'pubmed';   # the prefix of the id for the export file

# extracting all PMID values from the database "-coll"
my $dbconn		  =		MongoDB::MongoClient->new()->get_database('progenetix');
my $dbcoll      =   $dbconn->get_collection($args{'-coll'});
my $distincts		=		$dbconn->run_command([
										 "distinct"	=>	$args{'-coll'},
										 "key"     	=>	'PMID',
										 "query"   	=>	{},
										]);
my $pgPMIDs     =   $distincts->{values};

# extracting all existing PMID values from the standard "$currentPubs" directory
my @dirPMIDs;
opendir DIR, $currentPubs;
foreach (grep{ /$filetype/ } readdir(DIR)) {
  if ( /^$prefix\.(\d+?)\.$filetype/) {
    push(@dirPMIDs, $1);
  }
}
close DIR;


my $amga4ghbs   =   MongoDB::MongoClient->new()->get_database('arraymap_ga4gh')->get_collection('biosamples');
my $pgga4ghbs   =   MongoDB::MongoClient->new()->get_database('progenetix_ga4gh')->get_collection('biosamples');


# reformatting the publication entries & exporting them

my $progress_bar = Term::ProgressBar->new(scalar @$pgPMIDs);

for my $i (0..$#{ $pgPMID }) {

  my $pub       =   $dbcoll->find_one( { PMID => qr/^$pgPMIDs->[$i]$/ } );

  foreach (keys %$pub) {
    if ($pub->{$_} !~ /\w/)     { delete $pub->{$_} }
    if ($pub->{$_} =~ /^NA$/)   { delete $pub->{$_} }
  }

  my $pubDump   =   {
    label       =>  $pub->{CITETAG},
    authors     =>  $pub->{AUTHORS},
    title       =>  $pub->{TITLE},
    journal     =>  $pub->{JOURNAL},
    year        =>  1 * $pub->{YEAR},
    pmid        =>  1 * $pub->{PMID},
    abstract    =>  $pub->{ABSTRACT},
    contact     =>  {
      name      =>  $pub->{CONTACT},
      email     =>  $pub->{EMAIL},
    },
    counts      =>  {
      samples_ccgh      =>  1 * $pub->{NO_CCGH},
      samples_acgh      =>  1 * $pub->{NO_ACGH},
      samples_wes       =>  1 * $pub->{NO_WES},
      samples_wgs       =>  1 * $pub->{NO_WGS},
      biosamples        =>  1 * $pub->{SAMPLENO},
    },
    cancertypes =>  [],
    notes       =>  $pub->{PUBNOTE},
  };

  my $maxTechnique      =   (sort {$b <=> $a} ($pubDump->{counts}->{samples_ccgh}, $pubDump->{counts}->{samples_acgh}, $pubDump->{counts}->{samples_wes}, $pubDump->{counts}->{samples_wgs}))[0];

  if ($pubDump->{counts}->{biosamples} < $maxTechnique) {
    $pubDump->{counts}->{biosamples} = $maxTechnique }
  if ($pub->{INDIVIDUALNO} > 0) {
    $pubDump->{counts}->{individuals} = 1 * $pub->{INDIVIDUALNO} }

  $pubDump->{external_identifiers}      =   [];
  if ($pub->{PMID} =~ /^|\:\d{6,10}$/) {
    push(@{$pubDump->{external_identifiers}}, 'pubmed:'.$pub->{PMID}) }

  foreach my $accession (grep{ /\w\w\w/ } split(',', $pub->{ACCESSION})) {
    $accession  =~  s/[\w\.\:]\://g;
    if ($accession =~ /^GSE\d{2,10}$/) {
      push(@{$pubDump->{external_identifiers}}, 'geo:'.$accession) }
    if ($accession =~ /^EGAS\d{11}$/) {
      push(@{$pubDump->{external_identifiers}}, 'ega.study:'.$accession) }
    if ($accession =~ /^[AEP]-\w{4}-\d+$/) {
      push(@{$pubDump->{external_identifiers}}, 'arrayexpress:'.$accession) }
  }


  my %bioOntologies        =   ();

  # cancertype currently using SEER
  if ($pub->{CANCERTYPE} =~ /^seer\s(\d{5})\:\s*?(\w.*?)$/) {
    $bioOntologies{ 'seer:'.$1 } =   $2 }

  # from samples ...
  foreach my $coll ($amga4ghbs, $pgga4ghbs) {
    my $cursor	=		$coll->find( { "external_identifiers.identifier" => qr/^(?:(?:pubmed)|(?:pmid)\:)?$pub->{PMID}$/ } )->fields( { bio_characteristics => 1 } );
    my @samples	=		$cursor->all;
    foreach my $sample (@samples) {
      foreach my $bioC (@{$sample->{bio_characteristics}}) {
        foreach my $ontology (@{$bioC->{ontology_terms}}) {
          $bioOntologies{ $ontology->{term_id} } =   $ontology->{term_label};
        }
      }
    }
  }

  foreach (sort keys %bioOntologies) {
    push(
      @{ $pubDump->{cancertypes} },
      {
        term_id           =>  $_,
        term_label        =>  $bioOntologies{ $_ },
      }
    );
  }



  if ($pub->{geo_data}->{geo_json}->{coordinates}->[1] =~ /^\-?\d+?(\.\d)?\d*?$/) {
    $pubDump->{geo_data}        =  {
      geo_json  =>  $pub->{geo_data}->{geo_json},
      info      =>  {
        city    =>  $pub->{geo_data}->{info}->{city},
        country =>  $pub->{geo_data}->{info}->{country},
        continent       =>  $pub->{geo_data}->{info}->{continent},
        precision       =>  $pub->{geo_data}->{geo_precision},
        label   =>  $pub->{geo_data}->{geo_label},
      },
    };
  }

  # exporting the .yaml (or .json) file
  # if none of the technique counts are > 0, => review directory
  my $exportDir =   $currentPubs;
  if ($pubDump->{counts}->{biosamples} < 1) {
    $exportDir  =   $inPubs }

  my $pubFile   =   $exportDir.'/'.join('.', $prefix, $pgPMID, $args{'-filetype'} );
  if (
    (! -f $pubFile)
    ||
    $args{'-update'} =~ 'y'
  ) {
    if ($args{'-filetype'} =~ /json/) {
      open (FILE, ">:utf8", $pubFile);
      print	FILE  JSON::XS->new->pretty( 1 )->allow_blessed->convert_blessed->encode($pubDump);
      close FILE;
    } else {
      YAML::XS::DumpFile($pubFile, $pubDump);
    }
  }

  $progress_bar->update($i);

}

if ($args{'-cleanup'} =~ /y/) {
  foreach my $dirPMID (@dirPMIDs) {
    if (! grep { /^$dirPMID$/ } @$pgPMIDs) {
      my $cmd   =   join(' ',
        'mv',
        $currentPubs.'/'.join('.', $prefix, $dirPMID, $args{'-filetype'}),
        $excludePubs.'/'.join('.', $prefix, $dirPMID, $args{'-filetype'}),
      );
      `$cmd`;
    }
  }
}




################################################################################

sub _checkPathsExit {

  my ($currentPubs, $inPubs, $excludePubs)      =   @_;
  my $checkPaths  =   1;
  foreach ($currentPubs, $inPubs, $excludePubs) {
    if (! -d $_) {
      print <<END;

An existing "$_" directory has to exist.

END
      $checkPaths =   -1;
    }
    if ($checkPaths < 1) { exit }

  }

}


1;
